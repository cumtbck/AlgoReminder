import Foundation
import CoreData

// MARK: - 基于SM-2算法的科学间隔重复调度器
class SpacedRepetitionScheduler {
    static let shared = SpacedRepetitionScheduler()
    
    private init() {}
    
    // MARK: - 核心算法参数
    private let defaultEaseFactor: Float = 2.5
    private let minimumEaseFactor: Float = 1.3
    private let maximumInterval: TimeInterval = 365 * 24 * 60 * 60 // 1年
    private let initialInterval: TimeInterval = 24 * 60 * 60 // 1天
    
    // MARK: - 创建初始复习计划
    func createInitialReviewPlan(for problem: Problem, context: NSManagedObjectContext) -> ReviewPlan? {
        return UnifiedErrorHandler.shared.safeExecute(
            {
                let reviewPlan = ReviewPlan(context: context)
                reviewPlan.id = UUID()
                reviewPlan.problem = problem
                reviewPlan.status = ReviewStatus.pending.rawValue
                reviewPlan.intervalLevel = ReviewIntervalLevel.first.rawValue
                reviewPlan.scheduledAt = Date().addingTimeInterval(initialInterval)
                reviewPlan.easeFactor = defaultEaseFactor
                reviewPlan.difficultyAdjustment = 1.0
                
                // 更新问题统计
                problem.totalReviews = 0
                problem.averageScore = 0.0
                problem.streakCount = 0
                problem.createdAt = Date()
                problem.updatedAt = Date()
                
                try context.save()
                return reviewPlan
            },
            context: "Creating initial review plan",
            fallback: nil
        )
    }
    
    // MARK: - 完成复习并计算下一次间隔
    /// 协议要求的简化版本
    func completeReview(reviewPlan: ReviewPlan, score: Int, context: NSManagedObjectContext) -> ReviewPlan? {
        return completeReview(
            reviewPlan: reviewPlan,
            score: score,
            confidence: .medium,
            timeSpent: 0,
            context: context
        )
    }
    
    func completeReview(reviewPlan: ReviewPlan, 
                       score: Int, 
                       confidence: ConfidenceLevel,
                       timeSpent: TimeInterval,
                       context: NSManagedObjectContext) -> ReviewPlan? {
        
        guard let problem = reviewPlan.problem else { return nil }
        
        // 更新当前复习计划
        reviewPlan.status = ReviewStatus.completed.rawValue
        reviewPlan.score = Int16(score)
        reviewPlan.confidence = confidence.rawValue
        reviewPlan.timeSpent = Int32(timeSpent)
        reviewPlan.completedAt = Date()
        
        // 计算新的间隔参数 (SM-2算法)
        let newEaseFactor = calculateNewEaseFactor(
            currentEaseFactor: reviewPlan.easeFactor,
            quality: score
        )
        
        let newIntervalLevel = calculateNextIntervalLevel(
            currentLevel: ReviewIntervalLevel(rawValue: reviewPlan.intervalLevel) ?? .first,
            quality: score,
            easeFactor: newEaseFactor
        )
        
        let nextInterval = calculateInterval(
            level: newIntervalLevel,
            easeFactor: newEaseFactor,
            difficultyAdjustment: reviewPlan.difficultyAdjustment
        )
        
        // 更新问题统计
        updateProblemStats(problem: problem, score: score, timeSpent: timeSpent)
        
        // 创建下一次复习计划
        let nextReviewPlan = ReviewPlan(context: context)
        nextReviewPlan.id = UUID()
        nextReviewPlan.problem = problem
        nextReviewPlan.status = ReviewStatus.pending.rawValue
        nextReviewPlan.intervalLevel = newIntervalLevel.rawValue
        nextReviewPlan.scheduledAt = Date().addingTimeInterval(nextInterval)
        nextReviewPlan.easeFactor = newEaseFactor
        nextReviewPlan.difficultyAdjustment = reviewPlan.difficultyAdjustment
        
        do {
            try context.save()
            return nextReviewPlan
        } catch {
            print("Error completing review: \(error)")
            return nil
        }
    }
    
    // MARK: - 跳过复习
    func skipReview(reviewPlan: ReviewPlan, context: NSManagedObjectContext) -> ReviewPlan? {
        // 获取今天的复习列表
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // 找到今天最晚的复习时间
        let todayReviews = getTodayReviews(context: context)
        let latestTime = todayReviews
            .compactMap { $0.scheduledAt }
            .max() ?? calendar.date(byAdding: .hour, value: 23, to: today)!
        
        // 将当前复习移到今天最后
        let newScheduledTime = calendar.date(byAdding: .minute, value: 1, to: latestTime)!
        
        // 确保新时间还在今天
        if newScheduledTime < tomorrow {
            reviewPlan.scheduledAt = newScheduledTime
            
            do {
                try context.save()
                
                // 发送通知以更新UI（使用节流机制）
                NotificationThrottler.shared.postNotificationThrottled(name: .reviewSkipped, object: nil)
                
                return reviewPlan
            } catch {
                print("Error skipping review: \(error)")
                return nil
            }
        } else {
            // 如果已经到明天了，则保持原来的跳过逻辑
            guard let problem = reviewPlan.problem else { return nil }
            
            // 标记当前计划为跳过
            reviewPlan.status = ReviewStatus.skipped.rawValue
            
            // 创建新的复习计划，间隔不变但延迟到明天
            let nextReviewPlan = ReviewPlan(context: context)
            nextReviewPlan.id = UUID()
            nextReviewPlan.problem = problem
            nextReviewPlan.status = ReviewStatus.pending.rawValue
            nextReviewPlan.intervalLevel = reviewPlan.intervalLevel
            nextReviewPlan.scheduledAt = tomorrow
            nextReviewPlan.easeFactor = reviewPlan.easeFactor
            nextReviewPlan.difficultyAdjustment = reviewPlan.difficultyAdjustment
            
            do {
                try context.save()
                
                // 发送通知以更新UI（使用节流机制）
                NotificationThrottler.shared.postNotificationThrottled(name: .reviewSkipped, object: nil)
                
                return nextReviewPlan
            } catch {
                print("Error skipping review: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - 推迟复习
    func postponeReview(reviewPlan: ReviewPlan, days: Int, context: NSManagedObjectContext) -> Bool {
        let newDate = reviewPlan.scheduledAt?.addingTimeInterval(TimeInterval(days * 24 * 60 * 60)) ?? 
                      Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        
        reviewPlan.scheduledAt = newDate
        reviewPlan.status = ReviewStatus.postponed.rawValue
        
        // 轻微降低难度调整因子
        reviewPlan.difficultyAdjustment *= 0.95
        
        do {
            try context.save()
            return true
        } catch {
            print("Error postponing review: \(error)")
            return false
        }
    }
    
    // MARK: - 获取待复习项目
    /// 协议要求的版本
    func getDueReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        return getDueReviews(context: context, limit: nil)
    }
    
    func getDueReviews(context: NSManagedObjectContext, limit: Int? = nil) -> [ReviewPlan] {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND scheduledAt <= %@", 
                                      ReviewStatus.pending.rawValue, Date() as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)
        ]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching due reviews: \(error)")
            return []
        }
    }
    
    // MARK: - 获取今日复习
    func getTodayReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND scheduledAt >= %@ AND scheduledAt < %@", 
                                      ReviewStatus.pending.rawValue, today as NSDate, tomorrow as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching today reviews: \(error)")
            return []
        }
    }
    
    // MARK: - 获取逾期复习
    func getOverdueReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND scheduledAt < %@", 
                                      ReviewStatus.pending.rawValue, today as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching overdue reviews: \(error)")
            return []
        }
    }
    
    // MARK: - 计算下次复习时间预测
    func predictNextReviewDate(for problem: Problem, context: NSManagedObjectContext) -> Date? {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "problem == %@ AND status == %@", 
                                      problem, ReviewStatus.pending.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)
        ]
        request.fetchLimit = 1
        
        do {
            let reviews = try context.fetch(request)
            return reviews.first?.scheduledAt
        } catch {
            print("Error predicting next review date: \(error)")
            return nil
        }
    }
    
    // MARK: - 私有方法：SM-2算法实现
    
    private func calculateNewEaseFactor(currentEaseFactor: Float, quality: Int) -> Float {
        guard quality >= 0 && quality <= 5 else { return currentEaseFactor }
        
        // SM-2算法: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        let q = Float(quality)
        let adjustment = 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02)
        let newEaseFactor = currentEaseFactor + adjustment
        
        return max(minimumEaseFactor, min(newEaseFactor, 10.0))
    }
    
    private func calculateNextIntervalLevel(currentLevel: ReviewIntervalLevel, 
                                         quality: Int, 
                                         easeFactor: Float) -> ReviewIntervalLevel {
        
        guard quality >= 3 else {
            // 质量低于3，重置到第一级
            return .first
        }
        
        if quality >= 4 {
            // 质量良好，提升到下一级
            let allLevels = ReviewIntervalLevel.allCases.sorted { $0.rawValue < $1.rawValue }
            if let currentIndex = allLevels.firstIndex(of: currentLevel),
               currentIndex < allLevels.count - 1 {
                return allLevels[currentIndex + 1]
            }
        }
        
        // 保持当前级别
        return currentLevel
    }
    
    private func calculateInterval(level: ReviewIntervalLevel, 
                                 easeFactor: Float, 
                                 difficultyAdjustment: Float) -> TimeInterval {
        
        let baseInterval = TimeInterval(level.intervalDays * 24 * 60 * 60)
        
        // 应用ease因子调整
        let easeAdjustedInterval = baseInterval * TimeInterval(easeFactor)
        
        // 应用难度调整
        let finalInterval = easeAdjustedInterval * TimeInterval(difficultyAdjustment)
        
        return min(finalInterval, maximumInterval)
    }
    
    private func updateProblemStats(problem: Problem, score: Int, timeSpent: TimeInterval) {
        problem.lastPracticeAt = Date()
        problem.totalReviews += 1
        
        // 更新平均分
        let currentTotal = Float(problem.averageScore) * Float(problem.totalReviews - 1)
        let newAverage = (currentTotal + Float(score)) / Float(problem.totalReviews)
        problem.averageScore = newAverage
        
        // 更新掌握度
        updateMasteryLevel(problem: problem, score: score)
        
        // 更新连续计数
        if score >= 4 {
            problem.streakCount += 1
        } else {
            problem.streakCount = 0
        }
        
        problem.updatedAt = Date()
    }
    
    private func updateMasteryLevel(problem: Problem, score: Int) {
        let currentMastery = problem.mastery
        
        // 基于分数和复习次数调整掌握度
        var adjustment: Int16 = 0
        
        switch score {
        case 5:
            adjustment = 1 // 完全掌握，提升一级
        case 4:
            adjustment = currentMastery < MasteryLevel.proficient.rawValue ? 1 : 0
        case 3:
            adjustment = 0 // 保持现状
        case 2:
            adjustment = -1 // 需要巩固，降低一级
        case 0, 1:
            adjustment = -2 // 完全不会，大幅降低
        default:
            adjustment = 0
        }
        
        // 考虑复习次数的影响
        if problem.totalReviews > 5 && score >= 3 {
            adjustment = min(adjustment + 1, 1) // 多次复习后更容易提升
        }
        
        problem.mastery = max(MasteryLevel.notLearned.rawValue, 
                             min(MasteryLevel.mastered.rawValue, currentMastery + adjustment))
    }
    
    // MARK: - 高级功能
    
    func adjustDifficultyBasedOnPerformance(context: NSManagedObjectContext) {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", ReviewStatus.completed.rawValue)
        
        do {
            let completedReviews = try context.fetch(request)
            
            // 按算法类型分组分析表现
            let performanceByAlgorithm = Dictionary(grouping: completedReviews) {
                $0.problem?.algorithmType ?? "未分类"
            }
            
            for (algorithm, reviews) in performanceByAlgorithm {
                guard reviews.count >= 3 else { continue } // 需要足够样本
                
                let averageScore = reviews.reduce(0) { $0 + Int($1.score) } / reviews.count
                
                // 根据表现调整相关题目的难度因子
                let adjustmentFactor = averageScore >= 4 ? 1.05 : (averageScore <= 2 ? 0.95 : 1.0)
                
                for review in reviews {
                    if let problem = review.problem {
                        // 获取该问题的待复习计划
                        let pendingRequest: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
                        pendingRequest.predicate = NSPredicate(format: "problem == %@ AND status == %@", 
                                                            problem, ReviewStatus.pending.rawValue)
                        
                        let pendingReviews = try context.fetch(pendingRequest)
                        for pendingReview in pendingReviews {
                            pendingReview.difficultyAdjustment *= Float(adjustmentFactor)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("Error adjusting difficulty: \(error)")
        }
    }
}


extension SpacedRepetitionScheduler {
    
    func getReviewStatistics(for problem: Problem, context: NSManagedObjectContext) -> ReviewStatistics? {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "problem == %@", problem)
        
        do {
            let reviews = try context.fetch(request)
            let completedReviews = reviews.filter { $0.status == ReviewStatus.completed.rawValue }
            
            guard !completedReviews.isEmpty else { return nil }
            
            let totalReviews = completedReviews.count
            let averageScore = completedReviews.reduce(0) { $0 + Int($1.score) } / totalReviews
            let completionRate = Float(totalReviews) / Float(reviews.count)
            
            // 计算平均间隔
            let intervals = completedReviews.compactMap { review -> TimeInterval? in
                guard let completedAt = review.completedAt,
                      let scheduledAt = review.scheduledAt else { return nil }
                return scheduledAt.timeIntervalSince(completedAt)
            }
            let averageInterval = intervals.isEmpty ? 0 : intervals.reduce(0, +) / TimeInterval(intervals.count)
            
            return ReviewStatistics(
                totalReviews: totalReviews,
                averageScore: Float(averageScore),
                completionRate: completionRate,
                averageInterval: averageInterval,
                currentStreak: Int(problem.streakCount),
                longestStreak: Int(problem.streakCount),
                reviewsThisWeek: 0,
                reviewsThisMonth: 0
            )
        } catch {
            print("Error getting review statistics: \(error)")
            return nil
        }
    }
}