import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appConfig) private var appConfig
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @StateObject private var searchEngine = EnhancedSearchEngine.shared
    @StateObject private var pathManager = LearningPathManager.shared
    @StateObject private var settings = AppSettings.shared
    
    @State private var showingAddProblem = false
    @State private var showingReviewDashboard = false
    @State private var showingAddNote = false
    @State private var showingKnowledgeGraph = false
    @State private var showingLearningPaths = false
    @State private var showingRecommendations = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var selectedDifficulty = "全部"
    @State private var selectedAlgorithmType = "全部"
    @State private var selectedDataStructure = "全部"
    @State private var searchScope = "全部"
    @State private var activeTab = "problems" // "problems" or "notes"
    @State private var searchSuggestions: [SearchSuggestion] = []
    
    // 监听设置变化
    private let settingsChangedObserver = NotificationCenter.default.addObserver(
        forName: .appSettingsChanged,
        object: nil,
        queue: .main
    ) { _ in
        // 设置更改时强制重新渲染界面
        // 不需要手动调用 objectWillChange.send()，@StateObject 会自动处理
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Problem.title, ascending: true)],
        animation: .default)
    private var problems: FetchedResults<Problem>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>
    
        
    private var difficulties: [String] {
        let allDifficulties = problems.compactMap { $0.difficulty }
        return ["全部"] + Array(Set(allDifficulties)).sorted()
    }
    
    private var algorithmTypes: [String] {
        let allAlgorithmTypes = problems.compactMap { $0.algorithmType }
        return ["全部"] + Array(Set(allAlgorithmTypes)).sorted()
    }
    
    private var dataStructures: [String] {
        let allDataStructures = problems.compactMap { $0.dataStructure }
        return ["全部"] + Array(Set(allDataStructures)).sorted()
    }
    
    private var searchScopes: [String] {
        activeTab == "problems" ? ["全部", "题目名称", "算法类型", "数据结构", "技能标签", "题目来源"] : ["全部", "笔记标题", "笔记内容"]
    }
    
    private var filteredProblems: [Problem] {
        problems.filter { problem in
            let matchesSearch = searchText.isEmpty || matchesProblemSearchCriteria(problem)
            let matchesDifficulty = selectedDifficulty == "全部" || problem.difficulty == selectedDifficulty
            let matchesAlgorithmType = selectedAlgorithmType == "全部" || problem.algorithmType == selectedAlgorithmType
            let matchesDataStructure = selectedDataStructure == "全部" || problem.dataStructure == selectedDataStructure
            
            return matchesSearch && matchesDifficulty && matchesAlgorithmType && matchesDataStructure
        }
    }
    
    private var filteredNotes: [Note] {
        notes.filter { note in
            let matchesSearch = searchText.isEmpty || matchesNoteSearchCriteria(note)
            return matchesSearch
        }
    }
    
    private func matchesProblemSearchCriteria(_ problem: Problem) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        switch searchScope {
        case "全部":
            return (problem.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                   (problem.algorithmType?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                   (problem.dataStructure?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                   (problem.skillTags?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                   (problem.source?.localizedCaseInsensitiveContains(searchText) ?? false)
        case "题目名称":
            return problem.title?.localizedCaseInsensitiveContains(searchText) ?? false
        case "算法类型":
            return problem.algorithmType?.localizedCaseInsensitiveContains(searchText) ?? false
        case "数据结构":
            return problem.dataStructure?.localizedCaseInsensitiveContains(searchText) ?? false
        case "技能标签":
            return problem.skillTags?.localizedCaseInsensitiveContains(searchText) ?? false
        case "题目来源":
            return problem.source?.localizedCaseInsensitiveContains(searchText) ?? false
        default:
            return false
        }
    }
    
    private func matchesNoteSearchCriteria(_ note: Note) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        switch searchScope {
        case "全部":
            return (note.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                   (note.rawMarkdown?.localizedCaseInsensitiveContains(searchText) ?? false)
        case "笔记标题":
            return note.title?.localizedCaseInsensitiveContains(searchText) ?? false
        case "笔记内容":
            return note.rawMarkdown?.localizedCaseInsensitiveContains(searchText) ?? false
        default:
            return false
        }
    }
    
    private var searchPlaceholder: String {
        switch searchScope {
        case "全部":
            return activeTab == "problems" ? "搜索题目、算法、数据结构、标签..." : "搜索笔记标题、内容..."
        case "题目名称":
            return "搜索题目名称..."
        case "算法类型":
            return "搜索算法类型..."
        case "数据结构":
            return "搜索数据结构..."
        case "技能标签":
            return "搜索技能标签..."
        case "题目来源":
            return "搜索题目来源..."
        case "笔记标题":
            return "搜索笔记标题..."
        case "笔记内容":
            return "搜索笔记内容..."
        default:
            return "搜索..."
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Tab Bar (类似Edge浏览器)
            HStack(spacing: 0) {
                // Logo and Title
                HStack(spacing: 8) {
                    Image(systemName: AppSettings.shared.menuBarIconName)
                        .font(.title2)
                        .foregroundColor(AppSettings.shared.menuBarIconColor)

                    Text("素晴らしき日々～不連続存在～")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.leading, 16)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: { showingReviewDashboard = true }) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                    .help("今日复习")
                    
                    Button(action: { showingRecommendations = true }) {
                        Image(systemName: "sparkles")
                            .font(.body)
                            .foregroundColor(.purple)
                    }
                    .help("智能推荐")
                    
                    Button(action: { showingKnowledgeGraph = true }) {
                        Image(systemName: "network")
                            .font(.body)
                            .foregroundColor(.orange)
                    }
                    .help("知识图谱")
                    
                    Button(action: { showingLearningPaths = true }) {
                        Image(systemName: "map")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                    .help("学习路径")
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: AppSettings.shared.settingsIconName)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .help("设置")
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: { 
                        if activeTab == "problems" {
                            showingAddProblem = true
                        } else {
                            showingAddNote = true
                        }
                    }) {
                        Image(systemName: activeTab == "problems" ? AppSettings.shared.problemIconName : AppSettings.shared.noteIconName)
                            .font(.body)
                            .foregroundColor(.green)
                    }
                    .help(activeTab == "problems" ? "添加题目" : "添加笔记")
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content Area with Side Tabs
            HStack(spacing: 0) {
                // Left Sidebar (类似Edge的侧边栏)
                VStack(spacing: 0) {
                    // Tab Buttons
                    VStack(spacing: 0) {
                        Button(action: { activeTab = "problems" }) {
                            VStack(spacing: 4) {
                                Image(systemName: AppSettings.shared.problemIconName)
                                    .font(.system(size: 18))
                                Text("题目")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                activeTab == "problems" ? 
                                Color.blue.opacity(0.2) : 
                                Color.clear
                            )
                            .foregroundColor(activeTab == "problems" ? .blue : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { activeTab = "notes" }) {
                            VStack(spacing: 4) {
                                Image(systemName: AppSettings.shared.noteIconName)
                                    .font(.system(size: 18))
                                Text("笔记")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                activeTab == "notes" ? 
                                Color.purple.opacity(0.2) : 
                                Color.clear
                            )
                            .foregroundColor(activeTab == "notes" ? .purple : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Statistics
                    VStack(spacing: 8) {
                        Text("统计信息")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("题目总数")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(problems.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("笔记总数")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(notes.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            
                            let todayReviews = ReviewScheduler.shared.getTodayReviews(context: viewContext)
                            HStack {
                                Text("今日复习")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(todayReviews.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
                .frame(width: 80)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Main Content Area
                VStack(spacing: 0) {
                    // Search and Filter Bar
                    VStack(spacing: 12) {
                        HStack {
                            Picker("搜索范围", selection: $searchScope) {
                                ForEach(searchScopes, id: \.self) { scope in
                                    Text(scope).tag(scope)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: 120)
                            
                            TextField(searchPlaceholder, text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Spacer()
                            
                            Text("找到 \(activeTab == "problems" ? filteredProblems.count : filteredNotes.count) 个\(activeTab == "problems" ? "题目" : "笔记")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if activeTab == "problems" {
                            HStack {
                                Picker("算法类型", selection: $selectedAlgorithmType) {
                                    ForEach(algorithmTypes, id: \.self) { algorithmType in
                                        Text(algorithmType).tag(algorithmType)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: 120)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Content List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if activeTab == "problems" {
                                ForEach(filteredProblems, id: \.id) { problem in
                                    ProblemCard(problem: problem)
                                }
                            } else {
                                ForEach(filteredNotes, id: \.id) { note in
                                    NoteCard(note: note)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 900, minHeight: 600)
        }
        .sheet(isPresented: $showingAddProblem) {
            AddProblemView()
        }
        .sheet(isPresented: $showingReviewDashboard) {
            ReviewDashboardView()
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView()
        }
        .sheet(isPresented: $showingKnowledgeGraph) {
            KnowledgeGraphView(context: viewContext)
        }
        .sheet(isPresented: $showingLearningPaths) {
            LearningPathManagementView()
        }
        .sheet(isPresented: $showingRecommendations) {
            RecommendationDashboardView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onDismiss: {
                showingSettings = false
            })
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
