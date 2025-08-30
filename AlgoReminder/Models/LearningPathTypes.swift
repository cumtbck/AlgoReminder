import Foundation
import CoreData

// MARK: - 学习路径进度相关结构

struct LearningPathProgress {
    let overall: Float
    let completion: ProgressDimension
    let mastery: ProgressDimension
    let review: ProgressDimension
    let time: ProgressDimension
    let analysis: ProgressAnalysis
    let lastUpdated: Date
    
    static var empty: LearningPathProgress {
        LearningPathProgress(
            overall: 0,
            completion: ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0),
            mastery: ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0),
            review: ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0),
            time: ProgressDimension(value: 0, completed: 0, total: 0, started: 0, rate: 0),
            analysis: ProgressAnalysis(
                weakAreas: [],
                strongAreas: [],
                recommendations: [],
                insights: [],
                nextMilestones: [],
                estimatedCompletion: nil,
                learningSpeed: .steady
            ),
            lastUpdated: Date()
        )
    }
}

struct ProgressDimension {
    let value: Float
    let completed: Int
    let total: Int
    let started: Int
    let rate: Float
    
    var percentage: String {
        return String(format: "%.1f%%", value * 100)
    }
    
    var isComplete: Bool {
        return value >= 1.0
    }
    
    var hasStarted: Bool {
        return started > 0
    }
}

struct ProgressAnalysis {
    let weakAreas: [WeaknessArea]
    let strongAreas: [StrengthArea]
    let recommendations: [ProgressRecommendation]
    let insights: [ProgressInsight]
    let nextMilestones: [Milestone]
    let estimatedCompletion: Date?
    let learningSpeed: SpeedTrend
}

struct WeaknessArea {
    let category: String
    let description: String
    let severity: Float // 0.0 - 1.0
    let affectedProblems: Int
    let suggestedActions: [String]
    let priority: Int
}

struct StrengthArea {
    let category: String
    let description: String
    let proficiency: Float
    let masteredProblems: Int
    let achievements: [String]
}

struct ProgressRecommendation {
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Int
    let estimatedImpact: Float
    let actionItems: [String]
}

enum RecommendationType: String, CaseIterable {
    case review = "review"
    case practice = "practice"
    case study = "study"
    case takeBreak = "break"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .review: return "复习巩固"
        case .practice: return "加强练习"
        case .study: return "深入学习"
        case .takeBreak: return "适当休息"
        case .advanced: return "挑战进阶"
        }
    }
    
    var icon: String {
        switch self {
        case .review: return "arrow.clockwise"
        case .practice: return "figure.strengthtraining.traditional"
        case .study: return "book"
        case .takeBreak: return "cup.and.saucer"
        case .advanced: return "mountain.2"
        }
    }
}

struct ProgressInsight {
    let type: InsightType
    let title: String
    let description: String
    let data: [String: Any]
    let confidence: Float
}

enum InsightType: String, CaseIterable {
    case pattern = "pattern"
    case trend = "trend"
    case anomaly = "anomaly"
    case milestone = "milestone"
    case prediction = "prediction"
    
    var displayName: String {
        switch self {
        case .pattern: return "学习模式"
        case .trend: return "学习趋势"
        case .anomaly: return "异常情况"
        case .milestone: return "里程碑"
        case .prediction: return "预测分析"
        }
    }
}

struct Milestone {
    let title: String
    let description: String
    let targetProgress: Float
    let estimatedDate: Date?
    let isAchieved: Bool
    let reward: String?
}

struct WeightedMasteryResult {
    let score: Float
    let progress: Float
    let adjustmentFactor: Float
    let baseScore: Float
}

// MARK: - 学习速度分析相关

struct LearningSpeedAnalysis {
    let overallSpeed: Float // 题目/天
    let recentSpeed: Float   // 最近7天的速度
    let trend: SpeedTrend
    let consistency: Float  // 一致性评分 0-1
    let predictedCompletion: Date?
    let recommendations: [SpeedRecommendation]
}

enum SpeedTrend: String, CaseIterable {
    case accelerating = "accelerating"
    case steady = "steady"
    case decelerating = "decelerating"
    case inconsistent = "inconsistent"
    
    var displayName: String {
        switch self {
        case .accelerating: return "加速中"
        case .steady: return "稳定"
        case .decelerating: return "减速中"
        case .inconsistent: return "不稳定"
        }
    }
    
    var color: String {
        switch self {
        case .accelerating: return "green"
        case .steady: return "blue"
        case .decelerating: return "orange"
        case .inconsistent: return "red"
        }
    }
}

struct SpeedRecommendation {
    let type: SpeedRecommendationType
    let message: String
    let action: String
    let priority: Int
}

enum SpeedRecommendationType: String, CaseIterable {
    case maintainPace = "maintainPace"
    case increasePace = "increasePace"
    case decreasePace = "decreasePace"
    case takeBreak = "takeBreak"
    case focusOnQuality = "focusOnQuality"
    
    var displayName: String {
        switch self {
        case .maintainPace: return "保持节奏"
        case .increasePace: return "加快节奏"
        case .decreasePace: return "放慢节奏"
        case .takeBreak: return "适当休息"
        case .focusOnQuality: return "注重质量"
        }
    }
}

// MARK: - 进度计算器扩展

extension LearningPathProgressCalculator {
    
    func calculateOverallProgress(
        completion: ProgressDimension,
        mastery: ProgressDimension,
        review: ProgressDimension,
        time: ProgressDimension
    ) -> Float {
        // 加权平均计算综合进度
        let completionWeight: Float = 0.3
        let masteryWeight: Float = 0.4
        let reviewWeight: Float = 0.2
        let timeWeight: Float = 0.1
        
        let overallScore = completion.value * completionWeight +
                         mastery.value * masteryWeight +
                         review.value * reviewWeight +
                         time.value * timeWeight
        
        return min(max(overallScore, 0), 1)
    }
    
    func generateProgressAnalysis(
        path: LearningPath,
        problems: [Problem],
        completionProgress: ProgressDimension,
        masteryProgress: ProgressDimension,
        reviewProgress: ProgressDimension
    ) -> ProgressAnalysis {
        
        let weakAreas = identifyWeakAreas(problems: problems)
        let strongAreas = identifyStrongAreas(problems: problems)
        let recommendations = generateRecommendations(
            path: path,
            problems: problems,
            completionProgress: completionProgress,
            masteryProgress: masteryProgress,
            reviewProgress: reviewProgress
        )
        let insights = generateInsights(problems: problems)
        let nextMilestones = generateNextMilestones(path: path, currentProgress: completionProgress.value)
        let estimatedCompletion = calculateEstimatedCompletion(path: path, completionProgress: completionProgress)
        let learningSpeed = calculateLearningSpeed(problems: problems, completionProgress: completionProgress)
        
        return ProgressAnalysis(
            weakAreas: weakAreas,
            strongAreas: strongAreas,
            recommendations: recommendations,
            insights: insights,
            nextMilestones: nextMilestones,
            estimatedCompletion: estimatedCompletion,
            learningSpeed: learningSpeed
        )
    }
    
    private func identifyWeakAreas(problems: [Problem]) -> [WeaknessArea] {
        var weakAreas: [String: [Problem]] = [:]
        
        // 按算法类型分组
        for problem in problems {
            if problem.masteryLevel.rawValue < MasteryLevel.proficient.rawValue {
                if let algorithmType = problem.algorithmType {
                    weakAreas[algorithmType, default: []].append(problem)
                }
            }
        }
        
        return weakAreas.map { (algorithmType, problemList) in
            let avgMastery = problemList.reduce(0) { $0 + Float($1.mastery) } / Float(problemList.count)
            let severity = 1.0 - (avgMastery / Float(MasteryLevel.mastered.rawValue))
            
            return WeaknessArea(
                category: algorithmType,
                description: "\(algorithmType) 掌握度较低",
                severity: severity,
                affectedProblems: problemList.count,
                suggestedActions: [
                    "增加 \(algorithmType) 相关题目的练习频率",
                    "重点复习 \(algorithmType) 的基础概念",
                    "寻找 \(algorithmType) 的典型题目进行专项训练"
                ],
                priority: Int(severity * 10)
            )
        }.sorted { $0.priority > $1.priority }
    }
    
    private func identifyStrongAreas(problems: [Problem]) -> [StrengthArea] {
        var strongAreas: [String: [Problem]] = [:]
        
        // 按算法类型分组
        for problem in problems {
            if problem.masteryLevel.rawValue >= MasteryLevel.proficient.rawValue {
                if let algorithmType = problem.algorithmType {
                    strongAreas[algorithmType, default: []].append(problem)
                }
            }
        }
        
        return strongAreas.map { (algorithmType, problemList) in
            let avgMastery = problemList.reduce(0) { $0 + Float($1.mastery) } / Float(problemList.count)
            
            return StrengthArea(
                category: algorithmType,
                description: "\(algorithmType) 掌握良好",
                proficiency: avgMastery / Float(MasteryLevel.mastered.rawValue),
                masteredProblems: problemList.count,
                achievements: [
                    "已完成 \(problemList.count) 道 \(algorithmType) 题目",
                    "平均掌握度达到 \(String(format: "%.1f%%", avgMastery / Float(MasteryLevel.mastered.rawValue) * 100))",
                    "可以尝试更复杂的 \(algorithmType) 题目"
                ]
            )
        }.sorted { $0.proficiency > $1.proficiency }
    }
    
    private func generateRecommendations(
        path: LearningPath,
        problems: [Problem],
        completionProgress: ProgressDimension,
        masteryProgress: ProgressDimension,
        reviewProgress: ProgressDimension
    ) -> [ProgressRecommendation] {
        var recommendations: [ProgressRecommendation] = []
        
        // 基于完成度的推荐
        if completionProgress.value < 0.3 {
            recommendations.append(ProgressRecommendation(
                type: .study,
                title: "增加学习频率",
                description: "当前完成度较低，建议增加每日学习时间",
                priority: 9,
                estimatedImpact: 0.8,
                actionItems: [
                    "每天至少完成2道新题目",
                    "制定详细的学习计划",
                    "寻找学习伙伴互相监督"
                ]
            ))
        }
        
        // 基于掌握度的推荐
        if masteryProgress.value < 0.5 {
            recommendations.append(ProgressRecommendation(
                type: .review,
                title: "加强复习",
                description: "掌握度不足，需要重点复习已学内容",
                priority: 8,
                estimatedImpact: 0.7,
                actionItems: [
                    "复习掌握度较低的题目",
                    "总结错题和易错点",
                    "重新学习基础概念"
                ]
            ))
        }
        
        // 基于复习进度的推荐
        if reviewProgress.value < 0.4 {
            recommendations.append(ProgressRecommendation(
                type: .practice,
                title: "加强练习",
                description: "复习进度落后，需要增加练习频率",
                priority: 7,
                estimatedImpact: 0.6,
                actionItems: [
                    "每天安排专门的复习时间",
                    "使用间隔重复法提高记忆效果",
                    "做相关的练习题巩固记忆"
                ]
            ))
        }
        
        return recommendations.sorted { $0.priority > $1.priority }
    }
    
    private func generateInsights(problems: [Problem]) -> [ProgressInsight] {
        var insights: [ProgressInsight] = []
        
        // 分析学习模式
        let recentProblems = problems.prefix(10)
        let masteryTrend = analyzeMasteryTrend(recentProblems: Array(recentProblems))
        
        insights.append(ProgressInsight(
            type: .trend,
            title: "掌握度趋势",
            description: masteryTrend.description,
            data: ["trend": masteryTrend.direction, "change": masteryTrend.change],
            confidence: masteryTrend.confidence
        ))
        
        // 分析难度偏好
        let difficultyPreference = analyzeDifficultyPreference(problems: problems)
        insights.append(ProgressInsight(
            type: .pattern,
            title: "难度偏好",
            description: difficultyPreference.description,
            data: ["preferred": difficultyPreference.preferred, "avoided": difficultyPreference.avoided],
            confidence: difficultyPreference.confidence
        ))
        
        return insights
    }
    
    private func generateNextMilestones(path: LearningPath, currentProgress: Float) -> [Milestone] {
        var milestones: [Milestone] = []
        
        let milestonesData = [
            (progress: 0.25, title: "入门阶段", description: "完成25%的学习内容"),
            (progress: 0.5, title: "基础阶段", description: "完成50%的学习内容"),
            (progress: 0.75, title: "进阶阶段", description: "完成75%的学习内容"),
            (progress: 1.0, title: "精通阶段", description: "完成所有学习内容")
        ]
        
        for milestoneData in milestonesData {
            if Float(milestoneData.progress) > currentProgress {
                let estimatedDate = estimateCompletionDate(
                    path: path,
                    currentProgress: currentProgress,
                    targetProgress: Float(milestoneData.progress)
                )
                
                milestones.append(Milestone(
                    title: milestoneData.title,
                    description: milestoneData.description,
                    targetProgress: Float(milestoneData.progress),
                    estimatedDate: estimatedDate,
                    isAchieved: false,
                    reward: getRewardFor(milestone: milestoneData.title)
                ))
            }
        }
        
        return milestones
    }
    
    // MARK: - 辅助方法
    
    private func analyzeMasteryTrend(recentProblems: [Problem]) -> (direction: String, change: Float, confidence: Float, description: String) {
        guard recentProblems.count >= 3 else {
            return ("稳定", 0, 0.5, "数据不足，无法分析趋势")
        }
        
        let firstHalf = recentProblems.prefix(recentProblems.count / 2)
        let secondHalf = recentProblems.suffix(recentProblems.count / 2)
        
        let firstAvg = firstHalf.reduce(0) { $0 + Float($1.mastery) } / Float(firstHalf.count)
        let secondAvg = secondHalf.reduce(0) { $0 + Float($1.mastery) } / Float(secondHalf.count)
        
        let change = secondAvg - firstAvg
        let direction = change > 0.1 ? "上升" : (change < -0.1 ? "下降" : "稳定")
        let confidence = min(abs(change) * 5, 1.0)
        
        let description = "最近掌握度\(direction)，变化幅度为 \(String(format: "%.1f", change))"
        
        return (direction, change, confidence, description)
    }
    
    private func analyzeDifficultyPreference(problems: [Problem]) -> (preferred: String, avoided: String, confidence: Float, description: String) {
        let difficultyCounts = problems.reduce(into: [DifficultyLevel: Int]()) { counts, problem in
            counts[problem.difficultyLevel, default: 0] += 1
        }
        
        let sortedDifficulties = difficultyCounts.sorted { $0.value > $1.value }
        
        guard let mostPreferred = sortedDifficulties.first, let leastPreferred = sortedDifficulties.last else {
            return ("无", "无", 0, "数据不足")
        }
        
        let total = problems.count
        let confidence = Float(mostPreferred.value) / Float(total)
        
        let description = "偏好\(mostPreferred.key.displayName)题目，较少做\(leastPreferred.key.displayName)题目"
        
        return (mostPreferred.key.displayName, leastPreferred.key.displayName, confidence, description)
    }
    
    private func estimateCompletionDate(path: LearningPath, currentProgress: Float, targetProgress: Float) -> Date? {
        guard let startedAt = path.startedAt else { return nil }
        
        let timeElapsed = Date().timeIntervalSince(startedAt)
        let progressRate = currentProgress / Float(timeElapsed)
        
        guard progressRate > 0 else { return nil }
        
        let remainingProgress = targetProgress - currentProgress
        let estimatedRemainingTime = TimeInterval(remainingProgress / progressRate)
        
        return Date().addingTimeInterval(estimatedRemainingTime)
    }
    
    private func getRewardFor(milestone: String) -> String {
        switch milestone {
        case "入门阶段":
            return "🎉 初学者徽章"
        case "基础阶段":
            return "🏆 基础扎实徽章"
        case "进阶阶段":
            return "🌟 进阶学习者徽章"
        case "精通阶段":
            return "👑 精通大师徽章"
        default:
            return "🎖️ 学习成就徽章"
        }
    }
    
    private func calculateEstimatedCompletion(path: LearningPath, completionProgress: ProgressDimension) -> Date? {
        guard completionProgress.value > 0 && completionProgress.value < 1.0 else {
            return completionProgress.value >= 1.0 ? Date() : nil
        }
        
        let elapsedTime = Date().timeIntervalSince(path.startedAt ?? Date())
        let progressRate = Double(completionProgress.value) / elapsedTime
        let remainingProgress = 1.0 - Double(completionProgress.value)
        let estimatedRemainingTime = TimeInterval(remainingProgress / progressRate)
        
        return Date().addingTimeInterval(estimatedRemainingTime)
    }
    
    private func calculateLearningSpeed(problems: [Problem], completionProgress: ProgressDimension) -> SpeedTrend {
        guard !problems.isEmpty else { return .steady }
        
        let recentProblems = problems.suffix(10)
        let olderProblems = problems.prefix(upTo: max(0, problems.count - 10))
        
        if olderProblems.isEmpty {
            return .steady
        }
        
        let recentMastery = recentProblems.reduce(0) { $0 + Int($1.mastery) } / recentProblems.count
        let olderMastery = olderProblems.reduce(0) { $0 + Int($1.mastery) } / olderProblems.count
        
        let masteryDifference = recentMastery - olderMastery
        
        if Double(masteryDifference) > 1.0 {
            return .accelerating
        } else if Double(masteryDifference) < -1.0 {
            return .decelerating
        } else {
            return .steady
        }
    }
}