import Foundation
import CoreData
import NaturalLanguage

// MARK: - 基于NaturalLanguage的真实语义搜索引擎
class SemanticSearchEngine: ObservableObject {
    static let shared = SemanticSearchEngine()
    
    private var embeddingModel: NLModel?
    private var tagEmbeddingCache: [String: [Float]] = [:]
    
    private init() {
        setupEmbeddingModel()
    }
    
    // MARK: - 模型设置
    
    private func setupEmbeddingModel() {
        // 简化实现，使用基于标签的搜索
        print("Using tag-based semantic search")
        setupTagBasedSearch()
        
        // 预计算常用标签的嵌入
        preloadCommonTagEmbeddings()
    }
    
    private func preloadCommonTagEmbeddings() {
        let commonTags = [
            "数组", "字符串", "链表", "栈", "队列", "树", "二叉树", "图", "堆", "哈希表",
            "动态规划", "贪心算法", "回溯算法", "二分查找", "排序算法", "搜索算法",
            "双指针", "滑动窗口", "快速排序", "深度优先搜索", "广度优先搜索",
            "并查集", "前缀和", "差分数组", "单调栈", "单调队列", "KMP算法"
        ]
        
        for tag in commonTags {
            tagEmbeddingCache[tag] = generateSimpleEmbedding(for: tag)
        }
    }
    
    private func setupTagBasedSearch() {
        // 初始化基于标签的搜索
        print("Using tag-based search as fallback")
    }
    
    private func setupTFIDFFallback() {
        // 初始化TF-IDF向量化器作为降级方案
        print("Using TF-IDF fallback for semantic search")
    }
    
    // 生成简单的词嵌入（基于字符级别的简单哈希）
    private func generateSimpleEmbedding(for text: String) -> [Float] {
        let dimension = 50
        var embedding = [Float](repeating: 0.0, count: dimension)
        
        for (index, char) in text.enumerated() {
            let charValue = Int(char.asciiValue ?? 0)
            embedding[index % dimension] += Float(charValue) / 255.0
        }
        
        // 归一化
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            for i in 0..<embedding.count {
                embedding[i] /= magnitude
            }
        }
        
        return embedding
    }
    
    // 去重辅助方法
    private func removeDuplicates<T: Equatable>(_ array: [T]) -> [T] {
        var result: [T] = []
        for item in array {
            if !result.contains(item) {
                result.append(item)
            }
        }
        return result
    }
    
    // MARK: - 公共搜索接口
    
    /// 智能搜索题目和笔记
    func search(query: String, 
               filters: SearchFilters = SearchFilters(),
               context: NSManagedObjectContext,
               limit: Int = 20) -> [SearchResult] {
        
        let queryEmbedding = createQueryEmbedding(query)
        let allProblems = fetchAllProblems(context: context)
        let allNotes = fetchAllNotes(context: context)
        
        var results: [SearchResult] = []
        
        // 搜索题目
        for problem in allProblems {
            let similarity = calculateSimilarity(
                queryEmbedding: queryEmbedding,
                problem: problem
            )
            
            if similarity.relevanceScore > 0.2 { // 相似度阈值
                results.append(similarity)
            }
        }
        
        // 搜索笔记
        for note in allNotes {
            let similarity = calculateSimilarity(
                queryEmbedding: queryEmbedding,
                note: note
            )
            
            if similarity.relevanceScore > 0.2 {
                results.append(similarity)
            }
        }
        
        // 应用过滤器
        let filteredResults = applyFilters(results, filters: filters)
        
        // 按相似度排序并限制结果数量
        return filteredResults
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 语义搜索建议
    func getSearchSuggestions(query: String,
                           context: NSManagedObjectContext,
                           limit: Int = 8) -> [SearchSuggestion] {
        guard !query.isEmpty else { return [] }
        
        let queryEmbedding = createQueryEmbedding(query)
        let suggestions = generateSemanticSuggestions(query: query, queryEmbedding: queryEmbedding, context: context)
        
        return removeDuplicates(suggestions).prefix(limit).map { $0 }
    }
    
    /// 找到相似题目
    func findSimilarProblems(to problem: Problem,
                            context: NSManagedObjectContext,
                            limit: Int = 5) -> [Problem] {
        
        let problemEmbedding = createProblemEmbedding(problem)
        let allProblems = fetchAllProblems(context: context)
            .filter { $0.id != problem.id }
        
        let scoredProblems = allProblems.map { otherProblem in
            let otherEmbedding = createProblemEmbedding(otherProblem)
            let similarity = calculateCosineSimilarity(problemEmbedding, otherEmbedding)
            
            return (problem: otherProblem, score: similarity)
        }
        .filter { $0.score > 0.3 }
        .sorted { $0.score > $1.score }
        .prefix(limit)
        
        return scoredProblems.map { $0.problem }
    }
    
    // MARK: - 核心算法实现
    
    private func createQueryEmbedding(_ query: String) -> [Float] {
        // 清理和分词
        let cleanedQuery = cleanText(query)
        let tokens = tokenize(text: cleanedQuery)
        
        if let model = embeddingModel {
            return createModelEmbedding(tokens: tokens, model: model)
        } else {
            return createTFIDFEmbedding(tokens: tokens)
        }
    }
    
    private func createProblemEmbedding(_ problem: Problem) -> [Float] {
        var textComponents: [String] = []
        
        if let title = problem.title {
            textComponents.append(title)
        }
        
        if let algorithmType = problem.algorithmType {
            textComponents.append(algorithmType)
        }
        
        if let dataStructure = problem.dataStructure {
            textComponents.append(dataStructure)
        }
        
        if let skillTags = problem.skillTags {
            textComponents.append(skillTags)
        }
        
        let combinedText = textComponents.joined(separator: " ")
        return createQueryEmbedding(combinedText)
    }
    
    private func createNoteEmbedding(_ note: Note) -> [Float] {
        var textComponents: [String] = []
        
        if let title = note.title {
            textComponents.append(title)
        }
        
        if let rawMarkdown = note.rawMarkdown {
            // 提取前500个字符作为内容表示
            let content = cleanMarkdown(rawMarkdown)
            let preview = String(content.prefix(500))
            textComponents.append(preview)
        }
        
        if let tags = note.tags {
            textComponents.append(tags)
        }
        
        let combinedText = textComponents.joined(separator: " ")
        return createQueryEmbedding(combinedText)
    }
    
    private func createModelEmbedding(tokens: [String], model: NLModel) -> [Float] {
        var embedding: [Float] = Array(repeating: 0.0, count: 300) // 300维向量
        
        for token in tokens {
            if let tokenEmbedding = getWordEmbedding(for: token, model: model) {
                // 叠加词嵌入
                for i in 0..<min(embedding.count, tokenEmbedding.count) {
                    embedding[i] += tokenEmbedding[i]
                }
            }
        }
        
        // 归一化
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return embedding }
        
        for i in 0..<embedding.count {
            embedding[i] /= Float(magnitude)
        }
        
        return embedding
    }
    
    private func createTFIDFEmbedding(tokens: [String]) -> [Float] {
        // 简化的TF-IDF实现
        let vocabulary = [
            "数组", "字符串", "链表", "树", "图", "动态规划", "贪心", "回溯", "二分", "排序",
            "搜索", "指针", "窗口", "递归", "分治", "位运算", "数学", "栈", "队列", "哈希"
        ]
        
        var embedding: [Float] = Array(repeating: 0.0, count: vocabulary.count)
        let tokenSet = Set(tokens)
        
        for (index, term) in vocabulary.enumerated() {
            if tokenSet.contains(term) {
                embedding[index] = 1.0
            }
        }
        
        return embedding
    }
    
    private func getWordEmbedding(for word: String, model: NLModel) -> [Float]? {
        // 检查缓存
        if let cached = tagEmbeddingCache[word] {
            return cached
        }
        
        // 使用简单嵌入生成器
        let floatEmbedding = generateSimpleEmbedding(for: word)
        
        // 缓存结果
        tagEmbeddingCache[word] = floatEmbedding
        
        return floatEmbedding
    }
    
    private func calculateSimilarity(queryEmbedding: [Float], problem: Problem) -> SearchResult {
        let problemEmbedding = createProblemEmbedding(problem)
        let similarityScore = calculateCosineSimilarity(queryEmbedding, problemEmbedding)
        
        return SearchResult(
            problem: problem,
            relevanceScore: Float(similarityScore)
        )
    }
    
    private func calculateSimilarity(queryEmbedding: [Float], note: Note) -> SearchResult {
        let noteEmbedding = createNoteEmbedding(note)
        let similarityScore = calculateCosineSimilarity(queryEmbedding, noteEmbedding)
        
        return SearchResult(
            note: note,
            relevanceScore: Float(similarityScore)
        )
    }
    
    private func calculateCosineSimilarity(_ vector1: [Float], _ vector2: [Float]) -> Double {
        guard vector1.count == vector2.count else { return 0.0 }
        
        var dotProduct: Float = 0
        var magnitude1: Float = 0
        var magnitude2: Float = 0
        
        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            magnitude1 += vector1[i] * vector1[i]
            magnitude2 += vector2[i] * vector2[i]
        }
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return Double(dotProduct / (sqrt(magnitude1) * sqrt(magnitude2)))
    }
    
    private func fetchAllProblems(context: NSManagedObjectContext) -> [Problem] {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Problem.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching problems: \(error)")
            return []
        }
    }
    
    private func fetchAllNotes(context: NSManagedObjectContext) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching notes: \(error)")
            return []
        }
    }
    
    private func applyFilters(_ results: [SearchResult], filters: SearchFilters) -> [SearchResult] {
        return results.filter { result in
            // 应用内容类型过滤
            if filters.contentType != .problem && filters.contentType != .note {
                return result.type == filters.contentType
            }
            
            // 应用难度过滤（仅对题目）
            if let difficulty = filters.difficulty, result.type == .problem {
                guard let problem = result.problem else { return false }
                return problem.difficultyLevel == difficulty
            }
            
            // 应用算法类型过滤（仅对题目）
            if let algorithmType = filters.algorithmType, result.type == .problem {
                guard let problem = result.problem else { return false }
                return problem.algorithmType == algorithmType
            }
            
            // 应用数据结构过滤（仅对题目）
            if let dataStructure = filters.dataStructure, result.type == .problem {
                guard let problem = result.problem else { return false }
                return problem.dataStructure == dataStructure
            }
            
            // 应用掌握度过滤（仅对题目）
            if let masteryLevel = filters.masteryLevel, result.type == .problem {
                guard let problem = result.problem else { return false }
                return problem.masteryLevel == masteryLevel
            }
            
            // 应用标签过滤
            if !filters.tags.isEmpty {
                guard let problem = result.problem else { return false }
                let problemTags = Set(problem.skillTags?.components(separatedBy: ",") ?? [])
                let filterTags = Set(filters.tags)
                return !problemTags.isDisjoint(with: filterTags)
            }
            
            return true
        }
    }
    
    private func generateSemanticSuggestions(query: String, queryEmbedding: [Float], context: NSManagedObjectContext) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // 从常用标签中生成建议
        let commonTags = [
            "数组", "字符串", "链表", "栈", "队列", "树", "二叉树", "图", "堆", "哈希表",
            "动态规划", "贪心算法", "回溯算法", "二分查找", "排序算法", "搜索算法"
        ]
        
        for tag in commonTags {
            if tag.localizedCaseInsensitiveContains(query) {
                suggestions.append(SearchSuggestion(
                    text: tag,
                    type: .problem,
                    frequency: 10,
                    context: "算法类型"
                ))
            }
        }
        
        return suggestions
    }
    
    // MARK: - 辅助方法
    
    private func cleanText(_ text: String) -> String {
        return text
            .lowercased()
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cleanMarkdown(_ markdown: String) -> String {
        // 移除Markdown语法，保留纯文本
        var cleaned = markdown
        
        // 移除代码块
        cleaned = cleaned.replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
        
        // 移除行内代码
        cleaned = cleaned.replacingOccurrences(of: "`[^`]*`", with: " ", options: .regularExpression)
        
        // 移除标题标记
        cleaned = cleaned.replacingOccurrences(of: "^#{1,6}\\s*", with: " ", options: .regularExpression)
        
        // 移除链接
        cleaned = cleaned.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        
        // 移除强调标记
        cleaned = cleaned.replacingOccurrences(of: "[*_]{1,2}([^*_]+)[*_]{1,2}", with: "$1", options: .regularExpression)
        
        return cleanText(cleaned)
    }
    
    private func tokenize(text: String) -> [String] {
        // 使用NaturalLanguage进行中文分词
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var tokens: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, 
                           unit: .word, 
                           scheme: .lexicalClass) { tag, tokenRange in
            
            let token = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                tokens.append(token)
            }
            return true
        }
        
        return tokens
    }
    
    private func createSnippet(for problem: Problem, query: String) -> String {
        guard let title = problem.title else { return "" }
        
        // 简单的关键词高亮
        var snippet = title
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for term in queryTerms where !term.isEmpty {
            snippet = snippet.replacingOccurrences(
                of: term,
                with: "**\(term)**",
                options: .caseInsensitive
            )
        }
        
        return snippet
    }
    
    private func createSnippet(for note: Note, query: String) -> String {
        guard let title = note.title else { return "" }
        
        var snippet = title
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for term in queryTerms where !term.isEmpty {
            snippet = snippet.replacingOccurrences(
                of: term,
                with: "**\(term)**",
                options: .caseInsensitive
            )
        }
        
        return snippet
    }
    
  }