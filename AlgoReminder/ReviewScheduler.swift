import Foundation
import CoreData

// MARK: - 重构后的复习调度器（向后兼容）
class ReviewScheduler {
    static let shared = ReviewScheduler()
    
    // 使用新的科学间隔重复调度器
    private let spacedRepetitionScheduler = SpacedRepetitionScheduler.shared
    
    // 查询缓存机制
    private var queryCache: [String: (Date, [ReviewPlan])] = [:]
    private let cacheTimeout: TimeInterval = 30.0 // 30秒缓存
    
    private init() {}
    
    // MARK: - 向后兼容的公共接口
    
    func createInitialReviewPlan(for problem: Problem, context: NSManagedObjectContext) -> ReviewPlan? {
        return spacedRepetitionScheduler.createInitialReviewPlan(for: problem, context: context)
    }
    
    func completeReview(reviewPlan: ReviewPlan, score: Int, context: NSManagedObjectContext) -> ReviewPlan? {
        // 使用默认置信度级别完成复习
        let result = spacedRepetitionScheduler.completeReview(
            reviewPlan: reviewPlan, 
            score: score, 
            confidence: .medium, 
            timeSpent: 0, 
            context: context
        )
        
        // Update notification content after review completion
        NotificationManager.shared.updateNotificationContent()
        
        // 清除缓存以确保下次查询获取最新数据
        invalidateCacheOnDataChange()
        
        return result
    }
    
    func completeReview(reviewPlan: ReviewPlan, score: Int, confidence: ConfidenceLevel, timeSpent: TimeInterval, context: NSManagedObjectContext) {
        _ = spacedRepetitionScheduler.completeReview(
            reviewPlan: reviewPlan, 
            score: score, 
            confidence: confidence, 
            timeSpent: timeSpent, 
            context: context
        )
        
        NotificationManager.shared.updateNotificationContent()
        
        // 清除缓存以确保下次查询获取最新数据
        invalidateCacheOnDataChange()
    }
    
    func skipReview(reviewPlan: ReviewPlan, context: NSManagedObjectContext) {
        _ = spacedRepetitionScheduler.skipReview(reviewPlan: reviewPlan, context: context)
        NotificationManager.shared.updateNotificationContent()
        
        // 清除缓存以确保下次查询获取最新数据
        invalidateCacheOnDataChange()
        
        // 发送通知以更新UI（使用节流机制）
        NotificationThrottler.shared.postNotificationThrottled(name: .reviewSkipped, object: nil)
    }
    
    func postponeReview(reviewPlan: ReviewPlan, days: Int, context: NSManagedObjectContext) {
        _ = spacedRepetitionScheduler.postponeReview(reviewPlan: reviewPlan, days: days, context: context)
        NotificationManager.shared.updateNotificationContent()
        
        // 清除缓存以确保下次查询获取最新数据
        invalidateCacheOnDataChange()
    }
    
    // MARK: - 代理方法到新的调度器
    
    func getDueReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        let cacheKey = "due_reviews"
        
        // 检查缓存
        if let (timestamp, cachedResults) = queryCache[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            return cachedResults
        }
        
        // 执行查询
        let results = spacedRepetitionScheduler.getDueReviews(context: context)
        
        // 更新缓存
        queryCache[cacheKey] = (Date(), results)
        
        return results
    }
    
    func getTodayReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        let cacheKey = "today_reviews"
        
        // 检查缓存
        if let (timestamp, cachedResults) = queryCache[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            return cachedResults
        }
        
        // 执行查询
        let results = spacedRepetitionScheduler.getTodayReviews(context: context)
        
        // 更新缓存
        queryCache[cacheKey] = (Date(), results)
        
        return results
    }
    
    func getOverdueReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        let cacheKey = "overdue_reviews"
        
        // 检查缓存
        if let (timestamp, cachedResults) = queryCache[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            return cachedResults
        }
        
        // 执行查询
        let results = spacedRepetitionScheduler.getOverdueReviews(context: context)
        
        // 更新缓存
        queryCache[cacheKey] = (Date(), results)
        
        return results
    }
    
    // MARK: - 新增的高级功能
    
    func getReviewStatistics(for problem: Problem, context: NSManagedObjectContext) -> ReviewStatistics? {
        return spacedRepetitionScheduler.getReviewStatistics(for: problem, context: context)
    }
    
    func predictNextReviewDate(for problem: Problem, context: NSManagedObjectContext) -> Date? {
        return spacedRepetitionScheduler.predictNextReviewDate(for: problem, context: context)
    }
    
    func adjustDifficultyBasedOnPerformance(context: NSManagedObjectContext) {
        spacedRepetitionScheduler.adjustDifficultyBasedOnPerformance(context: context)
    }
    
    // MARK: - 缓存管理
    
    func clearCache() {
        queryCache.removeAll()
    }
    
    func clearCacheForQuery(_ cacheKey: String) {
        queryCache.removeValue(forKey: cacheKey)
    }
    
    // 在数据变更时清除相关缓存
    func invalidateCacheOnDataChange() {
        clearCache()
    }
}