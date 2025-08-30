import SwiftUI
import CoreData

struct ProblemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var problem: Problem
    
    @State private var showingNoteViewer = false
    @State private var showingEditProblem = false
    @State private var showingImportDialog = false
    
    private var reviews: [ReviewPlan] {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "problem == %@", problem)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: false)]
        
        return (try? viewContext.fetch(request)) ?? []
    }
    
    private var completedReviews: [ReviewPlan] {
        reviews.filter { $0.status == "completed" }
    }
    
    private var nextReview: ReviewPlan? {
        reviews.first { $0.status == "pending" }
    }
    
    private var notes: [Note] {
        guard let notesSet = problem.notes else { return [] }
        return Array(notesSet) as? [Note] ?? []
    }
    
    private var difficultyColor: Color {
        switch problem.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
    
    private var masteryLevel: String {
        switch problem.mastery {
        case 0: return "未掌握"
        case 1: return "初学"
        case 2: return "了解"
        case 3: return "熟悉"
        case 4: return "掌握"
        case 5: return "精通"
        default: return "未知"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("题目详情")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("编辑") {
                    showingEditProblem = true
                }
                .buttonStyle(PlainButtonStyle())
                
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("基本信息")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("标题：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(problem.title ?? "Untitled")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            HStack {
                                Text("来源：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(problem.source ?? "Custom")
                                    .font(.subheadline)
                                Spacer()
                            }
                            
                            if let url = problem.url {
                                HStack {
                                    Text("链接：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Link(url, destination: URL(string: url)!)
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Text("难度：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(problem.difficulty ?? "未知")
                                    .font(.subheadline)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(difficultyColor.opacity(0.2))
                                    .cornerRadius(4)
                                Spacer()
                            }
                            
                            if let category = problem.algorithmType {
                                HStack {
                                    Text("分类：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(category)
                                        .font(.subheadline)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.2))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Text("掌握程度：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(masteryLevel)
                                    .font(.subheadline)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                                Spacer()
                            }
                            
                            if let lastPractice = problem.lastPracticeAt {
                                HStack {
                                    Text("最后练习：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(lastPractice, style: .date)
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                            
                            if let tags = problem.skillTags, !tags.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("标签：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(tags.components(separatedBy: ","), id: \.self) { tag in
                                                Text(tag.trimmingCharacters(in: .whitespaces))
                                                    .font(.caption)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Review History
                    if !completedReviews.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("复习历史")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(completedReviews.prefix(5), id: \.id) { review in
                                    ReviewHistoryRow(review: review)
                                }
                                
                                if completedReviews.count > 5 {
                                    Text("还有 \(completedReviews.count - 5) 次复习记录...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Next Review
                    if let nextReview = nextReview {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("下次复习")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("计划时间：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(nextReview.scheduledAt ?? Date(), style: .date)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("复习次数：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("第 \(Int(nextReview.intervalLevel) + 1) 次复习")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("笔记")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(notes.isEmpty ? "导入笔记" : "查看笔记 (\(notes.count))") {
                                if notes.isEmpty {
                                    showingImportDialog = true
                                } else {
                                    showingNoteViewer = true
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(notes.prefix(3), id: \.id) { note in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(note.title ?? "Untitled Note")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            if let importedFrom = note.importedFromURL {
                                                Text("📎 \(URL(fileURLWithPath: importedFrom).lastPathComponent)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Text("更新于 \(note.updatedAt ?? Date(), style: .relative)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button("查看") {
                                            // This would open the specific note in a new window
                                            showingNoteViewer = true
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                if notes.count > 3 {
                                    Text("还有 \(notes.count - 3) 条笔记...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        } else {
                            Text("暂无笔记")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
        .onChange(of: showingNoteViewer) { show in
            // 当showingNoteViewer变为true时，打开独立窗口
            if show {
                showNoteViewerWindow()
                // 重置状态，因为我们不再使用sheet
                DispatchQueue.main.async {
                    showingNoteViewer = false
                }
            }
        }
        .sheet(isPresented: $showingEditProblem) {
            EditProblemView(problem: problem)
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .green
        default: return .gray
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource")
                    return
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                let content = try String(contentsOf: url, encoding: .utf8)
                importMarkdownContent(content, from: url)
            } catch {
                print("Error reading file: \(error)")
            }
        case .failure(let error):
            print("Error importing file: \(error)")
        }
    }
    
    private func importMarkdownContent(_ content: String, from url: URL) {
        // 使用导入文件的名称作为笔记标题
        let noteTitle = url.deletingPathExtension().lastPathComponent
        
        // 创建新笔记
        let newNote = Note(context: viewContext)
        newNote.id = UUID()
        newNote.title = noteTitle
        newNote.rawMarkdown = content
        newNote.importedFromURL = url.path
        newNote.noteType = "imported"
        newNote.updatedAt = Date()
        
        // 关联到当前题目
        newNote.addToProblems(problem)
        
        do {
            try viewContext.save()
            print("Successfully imported note: \(noteTitle)")
        } catch {
            print("Error saving imported note: \(error)")
        }
    }
    
    // 使用独立窗口打开笔记查看器
    private func showNoteViewerWindow() {
        // 使用ImprovedWindowManager打开独立窗口
        ImprovedWindowManager.shared.showNoteViewer(for: problem)
    }
}

struct EditProblemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appConfig) private var appConfig
    
    @ObservedObject var problem: Problem
    
    @State private var title = ""
    @State private var source = ""
    @State private var url = ""
    @State private var category = ""
    @State private var difficulty = ""
    @State private var tags = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var customSource = ""
    @State private var customCategory = ""
    @State private var customDifficulty = ""
    @State private var showingCustomSourceInput = false
    @State private var showingCustomCategoryInput = false
    @State private var showingCustomDifficultyInput = false
    
    // 使用统一配置管理器
    private var sources: [String] { appConfig.allSources }
    private var difficulties: [String] { appConfig.difficulties + ["自定义"] }
    private var categories: [String] { appConfig.algorithmTypes + ["自定义"] }
    
    init(problem: Problem) {
        self.problem = problem
        // Initialize state variables with problem values
        self._title = State(initialValue: problem.title ?? "")
        self._source = State(initialValue: problem.source ?? "")
        self._url = State(initialValue: problem.url ?? "")
        self._category = State(initialValue: problem.algorithmType ?? "")
        self._difficulty = State(initialValue: problem.difficulty ?? "")
        self._tags = State(initialValue: problem.skillTags ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("编辑题目")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Form
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标题 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入题目标题", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("来源 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if showingCustomSourceInput {
                            HStack {
                                TextField("输入自定义来源", text: $customSource)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button("取消") {
                                    showingCustomSourceInput = false
                                    customSource = ""
                                    source = "LeetCode"
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } else {
                            HStack {
                                Picker("来源", selection: $source) {
                                    ForEach(sources, id: \.self) { source in
                                        Text(source).tag(source)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: source) { newValue in
                                    if newValue == "自定义" {
                                        showingCustomSourceInput = true
                                        source = "LeetCode"
                                    }
                                }
                                
                                if source == "自定义" {
                                    Button("编辑") {
                                        showingCustomSourceInput = true
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入题目链接", text: $url)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("分类")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if showingCustomCategoryInput {
                                HStack {
                                    TextField("输入自定义分类", text: $customCategory)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("取消") {
                                        showingCustomCategoryInput = false
                                        customCategory = ""
                                        category = ""
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                HStack {
                                    Picker("分类", selection: $category) {
                                        Text("无").tag("")
                                        ForEach(categories, id: \.self) { category in
                                            Text(category).tag(category)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: category) { newValue in
                                        if newValue == "自定义" {
                                            showingCustomCategoryInput = true
                                            category = ""
                                        }
                                    }
                                    
                                    if category == "自定义" {
                                        Button("编辑") {
                                            showingCustomCategoryInput = true
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("难度")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if showingCustomDifficultyInput {
                                HStack {
                                    TextField("输入自定义难度", text: $customDifficulty)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("取消") {
                                        showingCustomDifficultyInput = false
                                        customDifficulty = ""
                                        difficulty = "中等"
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                HStack {
                                    Picker("难度", selection: $difficulty) {
                                        ForEach(difficulties, id: \.self) { difficulty in
                                            Text(difficulty).tag(difficulty)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: difficulty) { newValue in
                                        if newValue == "自定义" {
                                            showingCustomDifficultyInput = true
                                            difficulty = "中等"
                                        }
                                    }
                                    
                                    if difficulty == "自定义" {
                                        Button("编辑") {
                                            showingCustomDifficultyInput = true
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("用逗号分隔，如：数组,双指针", text: $tags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("提示：用逗号分隔多个标签")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("保存") {
                    saveProblem()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(title.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadProblemData()
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadProblemData() {
        title = problem.title ?? "Untitled"
        source = problem.source ?? "Custom"
        url = problem.url ?? ""
        category = problem.algorithmType ?? ""
        difficulty = problem.difficulty ?? ""
        tags = problem.skillTags ?? ""
    }
    
    private func saveProblem() {
        guard !title.isEmpty else {
            alertMessage = "请输入题目标题"
            showingAlert = true
            return
        }
        
        let finalSource: String
        if showingCustomSourceInput {
            finalSource = customSource
            // 添加到自定义来源列表
            appConfig.addCustomSource(customSource)
        } else {
            finalSource = source
        }
        
        problem.title = title
        problem.source = finalSource
        problem.url = url.isEmpty ? nil : url
        problem.algorithmType = showingCustomCategoryInput ? customCategory : (category.isEmpty ? nil : category)
        problem.difficulty = showingCustomDifficultyInput ? customDifficulty : difficulty
        problem.skillTags = tags.isEmpty ? nil : tags
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ReviewHistoryRow: View {
    let review: ReviewPlan
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Text(review.scheduledAt ?? Date(), style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("评分：\(review.score)")
                .font(.subheadline)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(scoreColor(Int(review.score)).opacity(0.2))
                .cornerRadius(4)
            
            Text("第 \(Int(review.intervalLevel) + 1) 次复习")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProblemDetailView(problem: {
        let context = PersistenceController.preview.container.viewContext
        let problem = Problem(context: context)
        problem.id = UUID()
        problem.title = "示例题目"
        problem.source = "LeetCode"
        problem.difficulty = "中等"
        problem.algorithmType = "数组"
        problem.skillTags = "数组,双指针"
        problem.mastery = 3
        problem.lastPracticeAt = Date()
        return problem
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
