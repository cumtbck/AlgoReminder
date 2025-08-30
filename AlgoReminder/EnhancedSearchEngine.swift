import Foundation
import CoreData
import NaturalLanguage

// MARK: - 重构后的搜索引擎（向后兼容）
class EnhancedSearchEngine: ObservableObject {
    static let shared = EnhancedSearchEngine()
    
    // 使用新的语义搜索引擎
    private let semanticSearchEngine = SemanticSearchEngine.shared
    
    private init() {}
    
    // MARK: - 向后兼容的公共接口
    
    /// 多维度搜索题目（兼容旧接口）
    func searchProblems(query: String,
                       filters: ProblemFilters,
                       context: NSManagedObjectContext) -> [Problem] {
        
        let searchFilters = SearchFilters(
            difficulty: filters.difficulty.flatMap { DifficultyLevel(rawValue: $0) },
            algorithmType: filters.algorithmType,
            dataStructure: filters.dataStructure,
            sortBy: convertSortOption(filters.sortBy)
        )
        
        let results = semanticSearchEngine.search(
            query: query,
            filters: searchFilters,
            context: context,
            limit: 100
        )
        
        // 提取Problem对象
        return results.compactMap { $0.problem }
    }
    
    /// 语义搜索（兼容旧接口）
    func semanticSearch(query: String,
                      context: NSManagedObjectContext,
                      limit: Int = 20) -> [SearchResult] {
        
        return semanticSearchEngine.search(
            query: query,
            filters: SearchFilters(),
            context: context,
            limit: limit
        )
    }
    
    /// 协议要求的搜索方法
    func search(query: String, filters: SearchFilters, context: NSManagedObjectContext, limit: Int) -> [SearchResult] {
        return semanticSearchEngine.search(
            query: query,
            filters: filters,
            context: context,
            limit: limit
        )
    }
    
        
        
    /// 智能搜索建议（兼容旧接口）
    func getSearchSuggestions(query: String,
                             context: NSManagedObjectContext,
                             limit: Int = 5) -> [SearchSuggestion] {
        
        return semanticSearchEngine.getSearchSuggestions(
            query: query,
            context: context,
            limit: limit
        )
    }
    
    // MARK: - 私有方法
    
    private func createTextSearchPredicate(for query: String) -> NSPredicate {
        let searchTerms = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if searchTerms.isEmpty {
            return NSPredicate(value: true)
        }
        
        let termPredicates = searchTerms.map { term in
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "title CONTAINS[c] %@", term),
                NSPredicate(format: "algorithmType CONTAINS[c] %@", term),
                NSPredicate(format: "dataStructure CONTAINS[c] %@", term),
                NSPredicate(format: "skillTags CONTAINS[c] %@", term),
                NSPredicate(format: "companies CONTAINS[c] %@", term),
                NSPredicate(format: "tags CONTAINS[c] %@", term)
            ])
        }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: termPredicates)
    }
    
    private func createSortDescriptors(from sortBy: SortBy) -> [NSSortDescriptor] {
        switch sortBy {
        case .relevance:
            return [NSSortDescriptor(keyPath: \Problem.frequency, ascending: false)]
        case .difficulty:
            return [NSSortDescriptor(keyPath: \Problem.difficulty, ascending: true)]
        case .mastery:
            return [NSSortDescriptor(keyPath: \Problem.mastery, ascending: true)]
        case .lastPracticed:
            return [NSSortDescriptor(keyPath: \Problem.lastPracticeAt, ascending: false)]
        case .title:
            return [NSSortDescriptor(keyPath: \Problem.title, ascending: true)]
        }
    }
    
    private func convertSortOption(_ oldSortBy: SortBy) -> SortOption {
        switch oldSortBy {
        case .relevance: return .relevance
        case .difficulty: return .difficulty
        case .mastery: return .mastery
        case .lastPracticed: return .lastPracticed
        case .title: return .title
        }
    }
    
    // MARK: - 新增的高级功能
    
    func findSimilarProblems(to problem: Problem, context: NSManagedObjectContext, limit: Int = 5) -> [Problem] {
        return semanticSearchEngine.findSimilarProblems(to: problem, context: context, limit: limit)
    }
    
    func getAllProblems(context: NSManagedObjectContext) -> [Problem] {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all problems: \(error)")
            return []
        }
    }
    
    func getAllNotes(context: NSManagedObjectContext) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all notes: \(error)")
            return []
        }
    }
}

// MARK: - 搜索相关模型

struct ProblemFilters {
    var difficulty: String?
    var algorithmType: String?
    var dataStructure: String?
    var source: String?
    var companies: [String]?
    var skillTags: [String]?
    var sortBy: SortBy = .relevance
}

enum SortBy: String, CaseIterable {
    case relevance = "相关性"
    case difficulty = "难度"
    case mastery = "掌握度"
    case lastPracticed = "最后练习"
    case title = "标题"
}


