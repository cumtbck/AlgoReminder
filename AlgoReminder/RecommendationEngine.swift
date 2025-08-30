import Foundation
import CoreData

class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()
    
    // 使用依赖注入
    private var container: DependencyContainer { DependencyContainer.shared }
    private var context: NSManagedObjectContext? {
        container.persistenceController.container.viewContext
    }
    
    private init() {
        // 自动设置，无需手动调用setup
    }
    
    // MARK: - 智能推荐方法
    
    /// 基于用户历史表现推荐题目
    func recommendProblemsBasedOnHistory(context: NSManagedObjectContext, 
                                      currentUser: String? = nil,
                                      limit: Int = 10) -> [Problem] {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Problem.lastPracticeAt, ascending: false)
        ]
        request.fetchLimit = limit * 2 // 获取更多以进行筛选
        
        do {
            let allProblems = try context.fetch(request)
            return scoredRecommendations(from: allProblems, context: context)
        } catch {
            print("Error fetching problems for recommendation: \(error)")
            return []
        }
    }
    
    /// 基于相似度推荐题目
    func recommendSimilarProblems(to problem: Problem, 
                                   context: NSManagedObjectContext,
                                   limit: Int = 5) -> [Problem] {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.predicate = NSPredicate(format: "id != %@", problem.id! as NSUUID)
        
        do {
            let allProblems = try context.fetch(request)
            let scoredProblems = allProblems.map { otherProblem in
                let score = calculateSimilarity(between: problem, and: otherProblem)
                return (problem: otherProblem, score: score)
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            
            return scoredProblems.map { $0.problem }
        } catch {
            print("Error fetching similar problems: \(error)")
            return []
        }
    }
    
    /// 基于知识点弱点推荐
    func recommendProblemsForWeakAreas(context: NSManagedObjectContext, 
                                      limit: Int = 8) -> [Problem] {
        // 分析用户在不同算法类型和数据结构上的表现
        let performanceByCategory = analyzePerformanceByCategory(context: context)
        
        // 找出表现最差的类别
        let weakCategories = performanceByCategory
            .filter { $0.averageScore < 3.0 }
            .sorted { $0.averageScore < $1.averageScore }
            .prefix(3)
        
        var recommendations: [Problem] = []
        
        for category in weakCategories {
            let request: NSFetchRequest<Problem> = Problem.fetchRequest()
            
            if category.type == "algorithm" {
                request.predicate = NSPredicate(format: "algorithmType == %@", category.name)
            } else {
                request.predicate = NSPredicate(format: "dataStructure == %@", category.name)
            }
            
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Problem.frequency, ascending: false),
                NSSortDescriptor(keyPath: \Problem.difficulty, ascending: true)
            ]
            request.fetchLimit = limit / weakCategories.count + 1
            
            do {
                let categoryProblems = try context.fetch(request)
                recommendations.append(contentsOf: categoryProblems)
            } catch {
                print("Error fetching problems for weak area \(category.name): \(error)")
            }
        }
        
        return Array(Set(recommendations)).prefix(limit).map { $0 }
    }
    
    /// 基于复习周期推荐
    func recommendProblemsForReview(context: NSManagedObjectContext, 
                                   limit: Int = 6) -> [ReviewPlan] {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND scheduledAt <= %@", 
                                      "pending", Date() as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)
        ]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching review plans: \(error)")
            return []
        }
    }
    
    // MARK: - 相似度计算
    
    private func calculateSimilarity(between problem1: Problem, and problem2: Problem) -> Double {
        var similarityScore: Double = 0.0
        
        // 算法类型相似性
        if let algo1 = problem1.algorithmType, let algo2 = problem2.algorithmType, algo1 == algo2 {
            similarityScore += 0.4
        }
        
        // 数据结构相似性
        if let ds1 = problem1.dataStructure, let ds2 = problem2.dataStructure, ds1 == ds2 {
            similarityScore += 0.3
        }
        
        // 难度相似性
        if problem1.difficulty == problem2.difficulty {
            similarityScore += 0.2
        }
        
        // 技能标签重叠
        if let tags1 = problem1.skillTags, let tags2 = problem2.skillTags {
            let tagSet1 = Set(tags1.components(separatedBy: ","))
            let tagSet2 = Set(tags2.components(separatedBy: ","))
            let intersection = tagSet1.intersection(tagSet2)
            let union = tagSet1.union(tagSet2)
            if !union.isEmpty {
                similarityScore += 0.1 * (Double(intersection.count) / Double(union.count))
            }
        }
        
        return similarityScore
    }
    
    // MARK: - 性能分析
    
    private func analyzePerformanceByCategory(context: NSManagedObjectContext) -> [CategoryPerformance] {
        var algorithmPerformance: [String: [Int]] = [:]
        var dataStructurePerformance: [String: [Int]] = [:]
        
        // 获取所有已完成的复习记录
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", "completed")
        
        do {
            let completedReviews = try context.fetch(request)
            
            for review in completedReviews {
                guard let problem = review.problem else { continue }
                let score = Int(review.score)
                
                // 算法类型统计
                if let algorithmType = problem.algorithmType {
                    if algorithmPerformance[algorithmType] == nil {
                        algorithmPerformance[algorithmType] = []
                    }
                    algorithmPerformance[algorithmType]?.append(score)
                }
                
                // 数据结构统计
                if let dataStructure = problem.dataStructure {
                    if dataStructurePerformance[dataStructure] == nil {
                        dataStructurePerformance[dataStructure] = []
                    }
                    dataStructurePerformance[dataStructure]?.append(score)
                }
            }
            
        } catch {
            print("Error analyzing performance: \(error)")
        }
        
        // 计算平均分
        var performance: [CategoryPerformance] = []
        
        for (algorithm, scores) in algorithmPerformance {
            let average = Double(scores.reduce(0, +)) / Double(scores.count)
            performance.append(CategoryPerformance(
                name: algorithm,
                type: "algorithm",
                averageScore: average,
                reviewCount: scores.count
            ))
        }
        
        for (dataStructure, scores) in dataStructurePerformance {
            let average = Double(scores.reduce(0, +)) / Double(scores.count)
            performance.append(CategoryPerformance(
                name: dataStructure,
                type: "dataStructure",
                averageScore: average,
                reviewCount: scores.count
            ))
        }
        
        return performance
    }
    
    private func scoredRecommendations(from problems: [Problem], context: NSManagedObjectContext) -> [Problem] {
        let currentDate = Date()
        let calendar = Calendar.current
        
        return problems.map { problem in
            var score: Double = 0.0
            
            // 基于掌握程度（推荐掌握程度较低的）
            score += Double(5 - problem.mastery) * 0.3
            
            // 基于最后练习时间（推荐很久没练习的）
            if let lastPractice = problem.lastPracticeAt {
                let daysSincePractice = calendar.dateComponents([.day], from: lastPractice, to: currentDate).day ?? 0
                score += Double(min(daysSincePractice, 30)) * 0.02
            } else {
                score += 0.6 // 从未练习过的给予更高优先级
            }
            
            // 基于频率（推荐高频题目）
            score += Double(problem.frequency) * 0.1
            
            // 基于难度（平衡不同难度）
            if problem.difficulty == "中等" {
                score += 0.2
            } else if problem.difficulty == "简单" {
                score += 0.1
            }
            
            return (problem: problem, score: score)
        }
        .sorted { $0.score > $1.score }
        .map { $0.problem }
    }
    
    // MARK: - Dashboard 推荐方法
    
    func getSmartRecommendations() -> [RecommendationResult] {
        guard let context = context else { return [] }
        
        let problems = recommendProblemsBasedOnHistory(context: context, limit: 6)
        return problems.map { problem in
            RecommendationResult(
                problem: problem,
                score: calculateRecommendationScore(for: problem),
                reason: generateReason(for: problem)
            )
        }
    }
    
    func getAllProblems() -> [Problem] {
        guard let context = context else { return [] }
        
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Problem.title, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all problems: \(error)")
            return []
        }
    }
    
    func getSimilarProblems(to problem: Problem) -> [Problem] {
        guard let context = context else { return [] }
        
        return recommendSimilarProblems(to: problem, context: context, limit: 4)
    }
    
    func analyzeWeaknessAreas() -> [WeaknessArea] {
        guard let context = context else { return [] }
        
        let problems = getAllProblems()
        
        // 按算法类型分组
        let algorithmGroups = Dictionary(grouping: problems) { $0.algorithmType ?? "未分类" }
        let algorithmWeaknesses = algorithmGroups.map { (algorithmType, problems) in
            let averageMastery = problems.reduce(0) { $0 + Double($1.mastery) } / Double(problems.count)
            let severity = 1.0 - Float(averageMastery / 5.0) // 将掌握度转换为严重程度
            
            return WeaknessArea(
                category: algorithmType,
                description: "\(algorithmType) 掌握度较低",
                severity: severity,
                affectedProblems: problems.count,
                suggestedActions: [
                    "练习更多 \(algorithmType) 类型的题目",
                    "复习 \(algorithmType) 的基础概念",
                    "分析错题，找出薄弱环节"
                ],
                priority: Int(severity * 10)
            )
        }
        
        // 按数据结构分组
        let dataStructureGroups = Dictionary(grouping: problems) { $0.dataStructure ?? "未分类" }
        let dataStructureWeaknesses = dataStructureGroups.map { (dataStructure, problems) in
            let averageMastery = problems.reduce(0) { $0 + Double($1.mastery) } / Double(problems.count)
            let severity = 1.0 - Float(averageMastery / 5.0) // 将掌握度转换为严重程度
            
            return WeaknessArea(
                category: dataStructure,
                description: "\(dataStructure) 掌握度较低",
                severity: severity,
                affectedProblems: problems.count,
                suggestedActions: [
                    "练习更多 \(dataStructure) 类型的题目",
                    "复习 \(dataStructure) 的基础概念",
                    "分析错题，找出薄弱环节"
                ],
                priority: Int(severity * 10)
            )
        }
        
        // 合并并筛选出弱点区域（严重程度大于0.3）
        return (algorithmWeaknesses + dataStructureWeaknesses)
            .filter { $0.severity > 0.3 }
            .sorted { $0.severity > $1.severity }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - 私有方法
    
    private func calculateRecommendationScore(for problem: Problem) -> Double {
        var score: Double = 0.0
        
        // 基于掌握程度
        score += Double(5 - problem.mastery) * 0.2
        
        // 基于频率
        score += Double(problem.frequency) * 0.1
        
        // 基于难度
        switch problem.difficulty {
        case "简单": score += 0.1
        case "中等": score += 0.2
        case "困难": score += 0.3
        default: break
        }
        
        return min(score, 1.0)
    }
    
    private func generateReason(for problem: Problem) -> String {
        if problem.mastery < 2 {
            return "掌握度较低，建议加强练习"
        } else if problem.mastery < 4 {
            return "继续练习以提高掌握度"
        } else {
            return "复习巩固知识点"
        }
    }
}

// MARK: - 推荐结果类型

struct RecommendationResult {
    let problem: Problem
    let score: Double
    let reason: String
}


// MARK: - 辅助结构

struct CategoryPerformance {
    let name: String
    let type: String // "algorithm" or "dataStructure"
    let averageScore: Double
    let reviewCount: Int
}

