import Foundation
import CoreData
import SwiftUI

// Import types from LearningPathTypes to avoid conflicts
typealias WeakArea = WeaknessArea
typealias LearningSpeed = SpeedTrend
typealias Recommendation = ProgressRecommendation

// Use existing types from LearningPathTypes
// ProgressDimension, ProgressAnalysis, and LearningPathProgress are already defined

// MARK: - 改进的学习路径进度计算器
class LearningPathProgressCalculator {
    static let shared = LearningPathProgressCalculator()
    
    private init() {}
    
    // MARK: - 核心进度计算
    
    func calculateProgress(for path: LearningPath) -> LearningPathProgress {
        guard let problems = path.problems?.allObjects as? [Problem] else {
            return LearningPathProgress.empty
        }
        
        guard !problems.isEmpty else {
            return LearningPathProgress.empty
        }
        
        // 计算各个维度的进度
        let completionProgress = calculateCompletionProgress(problems: problems)
        let masteryProgress = calculateMasteryProgress(problems: problems)
        let reviewProgress = calculateReviewProgress(problems: problems)
        let timeProgress = calculateTimeProgress(path: path, problems: problems)
        
        // 综合进度计算（加权平均）
        let overallProgress = calculateOverallProgress(
            completion: completionProgress,
            mastery: masteryProgress,
            review: reviewProgress,
            time: timeProgress
        )
        
        // 生成进度分析
        let analysis = generateProgressAnalysis(
            path: path,
            problems: problems,
            completionProgress: completionProgress,
            masteryProgress: masteryProgress,
            reviewProgress: reviewProgress
        )
        
        return LearningPathProgress(
            overall: overallProgress,
            completion: completionProgress,
            mastery: masteryProgress,
            review: reviewProgress,
            time: timeProgress,
            analysis: analysis,
            lastUpdated: Date()
        )
    }
    
    // MARK: - 分维度进度计算
    
    private func calculateCompletionProgress(problems: [Problem]) -> ProgressDimension {
        let totalProblems = problems.count
        let completedProblems = problems.filter { problem in
            problem.mastery >= MasteryLevel.proficient.rawValue
        }.count
        
        let startedProblems = problems.filter { problem in
            problem.mastery > MasteryLevel.notLearned.rawValue
        }.count
        
        let completionRate = totalProblems > 0 ? Float(completedProblems) / Float(totalProblems) : 0
        let startRate = totalProblems > 0 ? Float(startedProblems) / Float(totalProblems) : 0
        
        return ProgressDimension(
            value: completionRate,
            completed: completedProblems,
            total: totalProblems,
            started: startedProblems,
            rate: completionRate
        )
    }
    
    private func calculateMasteryProgress(problems: [Problem]) -> ProgressDimension {
        guard !problems.isEmpty else {
            return ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0)
        }
        
        let totalMasteryScore = problems.reduce(0) { $0 + Float($1.mastery) }
        let maxPossibleScore = Float(problems.count * Int(MasteryLevel.mastered.rawValue))
        let averageMastery = totalMasteryScore / Float(problems.count)
        
        // 考虑难度权重的调整后掌握度
        let weightedMastery = calculateWeightedMastery(problems: problems)
        
        return ProgressDimension(
            value: weightedMastery.progress,
            completed: Int(weightedMastery.score),
            total: Int(maxPossibleScore),
            started: problems.filter { $0.mastery > 0 }.count,
            rate: weightedMastery.progress
        )
    }
    
    private func calculateReviewProgress(problems: [Problem]) -> ProgressDimension {
        guard !problems.isEmpty else {
            return ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0)
        }
        
        let problemsWithReviews = problems.filter { problem in
            problem.totalReviews > 0
        }
        
        let totalReviews = problems.reduce(0) { $0 + Int($1.totalReviews) }
        let averageReviews = problems.isEmpty ? 0 : Float(totalReviews) / Float(problems.count)
        
        // 计算复习质量（基于平均分）
        let problemsWithScores = problems.filter { $0.averageScore > 0 }
        let averageScore = problemsWithScores.isEmpty ? 0 : 
            problemsWithScores.reduce(0) { $0 + Float($1.averageScore) } / Float(problemsWithScores.count)
        
        // 综合复习进度（考虑数量和质量）
        let reviewProgress = min((Float(problemsWithReviews.count) / Float(problems.count)) * 0.7 + 
                               (averageScore / 5.0) * 0.3, 1.0)
        
        return ProgressDimension(
            value: reviewProgress,
            completed: problemsWithReviews.count,
            total: problems.count,
            started: problemsWithReviews.count,
            rate: reviewProgress
        )
    }
    
    private func calculateTimeProgress(path: LearningPath, problems: [Problem]) -> ProgressDimension {
        guard let createdAt = path.createdAt else {
            return ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0)
        }
        
        let estimatedDuration = TimeInterval(path.estimatedDuration * 24 * 60 * 60) // 转换为秒
        let elapsedTime = Date().timeIntervalSince(createdAt)
        
        // 计算时间进度（不超过100%）
        let timeProgress = min(Float(elapsedTime / estimatedDuration), 1.0)
        
        // 考虑实际练习时间
        let totalPracticeTime = problems.reduce(0) { total, problem in
            let reviews = problem.reviewPlans?.compactMap { $0 as? ReviewPlan } ?? []
            let practiceTime = reviews.reduce(0) { $0 + Int($1.timeSpent) }
            return total + practiceTime
        }
        
        let expectedPracticeTime = Int(estimatedDuration / 60) // 预期练习时间（分钟）
        let practiceProgress = expectedPracticeTime > 0 ? 
            min(Float(totalPracticeTime) / Float(expectedPracticeTime), 1.0) : 0
        
        // 综合时间进度
        let finalTimeProgress = (timeProgress * 0.6 + practiceProgress * 0.4)
        
        return ProgressDimension(
            value: finalTimeProgress,
            completed: Int(elapsedTime),
            total: Int(estimatedDuration),
            started: problems.filter { $0.lastPracticeAt != nil }.count,
            rate: finalTimeProgress
        )
    }
    
      
    // MARK: - 辅助计算方法
    
    private func calculateWeightedMastery(problems: [Problem]) -> (score: Float, progress: Float) {
        var weightedScore: Float = 0
        var totalWeight: Float = 0
        
        for problem in problems {
            let difficulty = DifficultyLevel(rawValue: problem.difficulty ?? "") ?? .medium
            let weight = difficulty.weight
            let masteryScore = Float(problem.mastery)
            
            weightedScore += masteryScore * weight
            totalWeight += weight
        }
        
        let averageWeightedScore = totalWeight > 0 ? weightedScore / totalWeight : 0
        let progress = averageWeightedScore / Float(MasteryLevel.mastered.rawValue)
        
        return (score: averageWeightedScore, progress: progress)
    }
    
    private func identifyWeakAreas(problems: [Problem]) -> [WeakArea] {
        var weakAreas: [WeakArea] = []
        
        // 按算法类型分组
        let algorithmGroups = Dictionary(grouping: problems) { $0.algorithmType ?? "未分类" }
        for (algorithm, groupProblems) in algorithmGroups {
            let averageMastery = groupProblems.reduce(0) { $0 + Float($1.mastery) } / Float(groupProblems.count)
            if averageMastery < 3.0 {
                weakAreas.append(WeaknessArea(
                    category: algorithm,
                    description: "\(algorithm) 掌握度较低",
                    severity: 1.0 - Float(averageMastery / 5.0),
                    affectedProblems: groupProblems.count,
                    suggestedActions: [
                        "练习更多 \(algorithm) 类型的题目",
                        "复习 \(algorithm) 的基础概念"
                    ],
                    priority: Int((1.0 - Float(averageMastery / 5.0)) * 10)
                ))
            }
        }
        
        // 按数据结构分组
        let dataStructureGroups = Dictionary(grouping: problems) { $0.dataStructure ?? "未分类" }
        for (dataStructure, groupProblems) in dataStructureGroups {
            let averageMastery = groupProblems.reduce(0) { $0 + Float($1.mastery) } / Float(groupProblems.count)
            if averageMastery < 3.0 {
                weakAreas.append(WeaknessArea(
                    category: dataStructure,
                    description: "\(dataStructure) 掌握度较低",
                    severity: 1.0 - Float(averageMastery / 5.0),
                    affectedProblems: groupProblems.count,
                    suggestedActions: [
                        "练习更多 \(dataStructure) 类型的题目",
                        "复习 \(dataStructure) 的基础概念"
                    ],
                    priority: Int((1.0 - Float(averageMastery / 5.0)) * 10)
                ))
            }
        }
        
        return weakAreas.sorted { $0.severity > $1.severity }
    }
    
    private func calculateLearningSpeed(path: LearningPath, completionProgress: ProgressDimension) -> LearningSpeed {
        guard let createdAt = path.createdAt else { return .steady }
        
        let elapsedTime = Date().timeIntervalSince(createdAt)
        let elapsedDays = elapsedTime / (24 * 60 * 60)
        
        guard elapsedDays > 0 else { return .steady }
        
        let completionRate = completionProgress.rate
        let speed = completionRate / Float(elapsedDays) // 每天完成率
        
        // 判断学习速度
        if speed > 0.1 { // 每天完成10%以上
            return .accelerating
        } else if speed > 0.05 { // 每天完成5%以上
            return .steady
        } else if speed > 0.02 { // 每天完成2%以上
            return .decelerating
        } else {
            return .inconsistent
        }
    }
    
    private func predictCompletionTime(path: LearningPath,
                                      currentProgress: Float,
                                      learningSpeed: LearningSpeed) -> Date? {
        
        guard currentProgress < 1.0 else { return Date() } // 已经完成
        
        let remainingProgress = 1.0 - currentProgress
        
        // 根据学习速度预测剩余时间
        let dailyProgress: Float
        switch learningSpeed {
        case .accelerating: dailyProgress = 0.1
        case .steady: dailyProgress = 0.05
        case .decelerating: dailyProgress = 0.02
        case .inconsistent: dailyProgress = 0.01
        }
        
        let remainingDays = Int(ceil(remainingProgress / dailyProgress))
        let completionDate = Calendar.current.date(byAdding: .day, value: remainingDays, to: Date())
        
        return completionDate
    }
    
    private func generateRecommendations(path: LearningPath,
                                       problems: [Problem],
                                       completionProgress: ProgressDimension,
                                       masteryProgress: ProgressDimension,
                                       reviewProgress: ProgressDimension,
                                       weakAreas: [WeakArea]) -> [Recommendation] {
        
        var recommendations: [Recommendation] = []
        
        // 基于完成度的建议
        if completionProgress.value < 0.3 {
            recommendations.append(ProgressRecommendation(
                type: .practice,
                title: "增加练习频率",
                description: "目前完成度较低，建议增加每日练习量",
                priority: 1,
                estimatedImpact: 0.8,
                actionItems: ["每天至少完成2-3个题目", "重点练习薄弱环节"]
            ))
        }
        
        // 基于掌握度的建议
        if masteryProgress.value < 0.5 {
            recommendations.append(ProgressRecommendation(
                type: .study,
                title: "专注薄弱环节",
                description: "整体掌握度有待提高",
                priority: 1,
                estimatedImpact: 0.9,
                actionItems: ["优先练习掌握度较低的题目", "复习基础概念"]
            ))
        }
        
        // 基于复习情况的建议
        if reviewProgress.value < 0.4 {
            recommendations.append(ProgressRecommendation(
                type: .review,
                title: "加强复习",
                description: "复习覆盖率不足，容易遗忘",
                priority: 2,
                estimatedImpact: 0.7,
                actionItems: ["及时完成复习任务", "使用间隔重复法"]
            ))
        }
        
        // 基于薄弱环节的建议
        for weakArea in weakAreas.prefix(3) {
            recommendations.append(ProgressRecommendation(
                type: .practice,
                title: "加强\(weakArea.category)练习",
                description: "\(weakArea.category)平均掌握度较低",
                priority: 1,
                estimatedImpact: 0.8,
                actionItems: ["重点练习相关题目", "查看相关教程"]
            ))
        }
        
        return recommendations.sorted { $0.priority < $1.priority }
    }
    
    private func calculateSeverity(for mastery: Float) -> String {
        if mastery < 1.5 { return "critical" }
        if mastery < 2.5 { return "high" }
        if mastery < 3.5 { return "medium" }
        return "low"
    }
}

