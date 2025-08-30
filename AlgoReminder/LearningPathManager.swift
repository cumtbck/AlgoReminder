import SwiftUI
import CoreData

class LearningPathManager: ObservableObject {
    static let shared = LearningPathManager()
    
    // 使用依赖注入
    private var container: DependencyContainer { DependencyContainer.shared }
    private var context: NSManagedObjectContext? {
        container.persistenceController.container.viewContext
    }
    
    @Published var learningPaths: [LearningPath] = []
    @Published var activePath: LearningPath?
    
    private init() {
        // 自动设置，无需手动调用setup
        loadLearningPaths()
    }
    
    // MARK: - 学习路径管理
    
    func createLearningPath(name: String,
                           description: String,
                           difficulty: String,
                           tags: [String]) -> LearningPath? {
        guard let context = context else { return nil }
        
        let path = LearningPath(context: context)
        path.id = UUID()
        path.name = name
        path.pathDescription = description
        path.difficulty = difficulty
        path.tags = tags.joined(separator: ",")
        path.createdAt = Date()
        path.isActive = true
        path.progress = 0.0
        
        do {
            try context.save()
            learningPaths.append(path)
            activePath = path
            return path
        } catch {
            print("Error creating learning path: \(error)")
            return nil
        }
    }
    
    func addProblemToPath(_ problem: Problem, to path: LearningPath) -> Bool {
        guard let context = context else { return false }
        
        problem.learningPath = path
        updatePathProgress(path)
        
        do {
            try context.save()
            return true
        } catch {
            print("Error adding problem to path: \(error)")
            return false
        }
    }
    
    func removeProblemFromPath(_ problem: Problem) -> Bool {
        guard let context = context else { return false }
        
        if let path = problem.learningPath {
            problem.learningPath = nil
            updatePathProgress(path)
            
            do {
                try context.save()
                return true
            } catch {
                print("Error removing problem from path: \(error)")
                return false
            }
        }
        
        return true
    }
    
    func setActivePath(_ path: LearningPath) {
        // 取消之前活跃的路径
        if let activePath = activePath {
            activePath.isActive = false
        }
        
        // 设置新的活跃路径
        path.isActive = true
        activePath = path
        
        do {
            try context?.save()
        } catch {
            print("Error setting active path: \(error)")
        }
    }
    
    func deleteLearningPath(_ path: LearningPath) -> Bool {
        guard let context = context else { return false }
        
        // 移除路径中所有问题的关联
        if let problems = path.problems?.allObjects as? [Problem] {
            for problem in problems {
                problem.learningPath = nil
            }
        }
        
        context.delete(path)
        learningPaths.removeAll { $0.id == path.id }
        
        if activePath?.id == path.id {
            activePath = nil
        }
        
        do {
            try context.save()
            return true
        } catch {
            print("Error deleting learning path: \(error)")
            return false
        }
    }
    
    // MARK: - 智能路径推荐
    
    func generateRecommendedPaths() -> [LearningPathTemplate] {
        return [
            LearningPathTemplate(
                name: "算法基础入门",
                pathDescription: "适合初学者的算法基础知识学习路径",
                difficulty: "简单",
                estimatedDuration: 30, // 天
                tags: ["基础", "算法"],
                problemTypes: ["排序", "搜索", "递归"],
                prerequisites: []
            ),
            LearningPathTemplate(
                name: "数据结构精通",
                pathDescription: "深入学习各种数据结构的应用",
                difficulty: "中等",
                estimatedDuration: 45,
                tags: ["数据结构", "进阶"],
                problemTypes: ["数组", "链表", "树", "图"],
                prerequisites: ["算法基础入门"]
            ),
            LearningPathTemplate(
                name: "动态规划专项训练",
                pathDescription: "攻克动态规划难题的系统训练",
                difficulty: "困难",
                estimatedDuration: 60,
                tags: ["动态规划", "困难"],
                problemTypes: ["动态规划", "背包问题", "最长子序列"],
                prerequisites: ["算法基础入门", "数据结构精通"]
            ),
            LearningPathTemplate(
                name: "字符串处理专家",
                pathDescription: "字符串相关算法的全面学习",
                difficulty: "中等",
                estimatedDuration: 40,
                tags: ["字符串", "专项"],
                problemTypes: ["字符串匹配", "正则表达式", "编辑距离"],
                prerequisites: ["算法基础入门"]
            ),
            LearningPathTemplate(
                name: "图论算法大师",
                pathDescription: "图算法的深入学习和应用",
                difficulty: "困难",
                estimatedDuration: 50,
                tags: ["图论", "高级"],
                problemTypes: ["最短路径", "最小生成树", "网络流"],
                prerequisites: ["数据结构精通"]
            )
        ]
    }
    
    func createPathFromTemplate(_ template: LearningPathTemplate) -> LearningPath? {
        return createLearningPath(
            name: template.name,
            description: template.pathDescription,
            difficulty: template.difficulty,
            tags: template.tags
        )
    }
    
    func getRecommendedProblems(for path: LearningPath) -> [Problem] {
        guard let context = context else { return [] }
        
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        
        // 根据路径名称和标签推荐相关题目
        var predicates: [NSPredicate] = []
        
        // 排除已经在路径中的题目
        let existingProblemIDs = path.problems?.compactMap { ($0 as? Problem)?.id } ?? []
        if !existingProblemIDs.isEmpty {
            predicates.append(NSPredicate(format: "NOT (id IN %@)", existingProblemIDs))
        }
        
        // 根据路径难度筛选
        predicates.append(NSPredicate(format: "difficulty == %@", path.difficulty ?? "中等"))
        
        // 根据标签筛选
        let pathTags = path.tags?.components(separatedBy: ",") ?? []
        if !pathTags.isEmpty {
            let tagPredicates = pathTags.map { tag in
                NSPredicate(format: "skillTags CONTAINS[c] %@", tag)
            }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: tagPredicates))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Problem.frequency, ascending: false),
            NSSortDescriptor(keyPath: \Problem.mastery, ascending: true)
        ]
        request.fetchLimit = 10
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error getting recommended problems: \(error)")
            return []
        }
    }
    
    // MARK: - 私有方法
    
    private func loadLearningPaths() {
        guard let context = context else { return }
        
        let request: NSFetchRequest<LearningPath> = LearningPath.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \LearningPath.createdAt, ascending: false)
        ]
        
        do {
            learningPaths = try context.fetch(request)
            activePath = learningPaths.first { $0.isActive }
        } catch {
            print("Error loading learning paths: \(error)")
        }
    }
    
    private func updatePathProgress(_ path: LearningPath) {
        // 使用新的进度计算器
        let progress = LearningPathProgressCalculator.shared.calculateProgress(for: path)
        
        // 更新路径的进度字段
        path.progress = progress.overall
        path.totalProblems = Int32(progress.completion.total)
        path.completedProblems = Int32(progress.completion.completed)
        path.masteryProgress = progress.mastery.value
        
        // 如果路径刚刚完成，设置完成时间
        if progress.overall >= 1.0 && path.completedAt == nil {
            path.completedAt = Date()
            path.isActive = false
        }
        
        do {
            try context?.save()
        } catch {
            print("Error updating path progress: \(error)")
        }
    }
    
    func refreshPaths() {
        guard let context = context else { return }
        
        loadLearningPaths()
        
        // 更新所有路径的进度
        for path in learningPaths {
            updatePathProgress(path)
        }
    }
}

// MARK: - 学习路径模板

struct LearningPathTemplate {
    let name: String
    let pathDescription: String
    let difficulty: String
    let estimatedDuration: Int // 天数
    let tags: [String]
    let problemTypes: [String]
    let prerequisites: [String]
}

// MARK: - 学习路径统计

struct LearningPathStats {
    let totalPaths: Int
    let activePaths: Int
    let completedPaths: Int
    let averageProgress: Float
    let totalProblems: Int
    let completedProblems: Int
}

extension LearningPathManager {
    func getPathStats() -> LearningPathStats {
        let totalPaths = learningPaths.count
        let activePaths = learningPaths.filter { $0.isActive }.count
        
        let completedPaths = learningPaths.filter { path in
            path.progress >= 1.0
        }.count
        
        let averageProgress = learningPaths.isEmpty ? 0.0 :
            learningPaths.reduce(0.0) { $0 + $1.progress } / Float(totalPaths)
        
        let totalProblems = learningPaths.reduce(0) { total, path in
            total + (path.problems?.count ?? 0)
        }
        
        let completedProblems = learningPaths.reduce(0) { total, path in
            total + (path.problems?.compactMap { ($0 as? Problem)?.mastery ?? 0 >= MasteryLevel.proficient.rawValue ? 1 : 0 }.reduce(0, +) ?? 0)
        }
        
        return LearningPathStats(
            totalPaths: totalPaths,
            activePaths: activePaths,
            completedPaths: completedPaths,
            averageProgress: averageProgress,
            totalProblems: totalProblems,
            completedProblems: completedProblems
        )
    }
    
    // MARK: - 新增的高级功能
    
    func getProgressDetails(for path: LearningPath) -> LearningPathProgress? {
        return LearningPathProgressCalculator.shared.calculateProgress(for: path)
    }
    
    func getWeakAreas(for path: LearningPath) -> [WeakArea] {
        let progress = getProgressDetails(for: path)
        return progress?.analysis.weakAreas ?? []
    }
    
    func getRecommendations(for path: LearningPath) -> [Recommendation] {
        let progress = getProgressDetails(for: path)
        return progress?.analysis.recommendations ?? []
    }
    
    func estimateCompletionTime(for path: LearningPath) -> Date? {
        let progress = getProgressDetails(for: path)
        return progress?.analysis.estimatedCompletion
    }
    
    func getLearningSpeed(for path: LearningPath) -> LearningSpeed {
        let progress = getProgressDetails(for: path)
        return progress?.analysis.learningSpeed ?? .steady
    }
}