import SwiftUI
import CoreData

struct LearningPathDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var path: LearningPath
    @ObservedObject private var pathManager = LearningPathManager.shared
    @State private var showingAddProblems = false
    @State private var recommendedProblems: [Problem] = []
    
    private var pathProblems: [Problem] {
        guard let problemsSet = path.problems else { return [] }
        return (problemsSet.allObjects as? [Problem] ?? []).sorted { ($0.title ?? "") < ($1.title ?? "") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.name ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("学习路径详情")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
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
                    // Path Info
                    PathInfoSection(path: path)
                    
                    // Progress Section
                    ProgressSection(path: path)
                    
                    // Problems Section
                    ProblemsSection(
                        problems: pathProblems,
                        onAddProblems: {
                            showingAddProblems = true
                            recommendedProblems = pathManager.getRecommendedProblems(for: path)
                        }
                    )
                    
                    // Recommended Problems
                    if !recommendedProblems.isEmpty {
                        RecommendedProblemsSection(
                            problems: recommendedProblems,
                            path: path,
                            onAdd: { problem in
                                _ = pathManager.addProblemToPath(problem, to: path)
                                pathManager.refreshPaths()
                                recommendedProblems = pathManager.getRecommendedProblems(for: path)
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 900, height: 700)
        .onAppear {
            // Setup handled by shared instance
        }
        .sheet(isPresented: $showingAddProblems) {
            AddProblemsToPathView(
                path: path,
                recommendedProblems: recommendedProblems
            )
        }
    }
}

// MARK: - 路径信息部分

struct PathInfoSection: View {
    @ObservedObject var path: LearningPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("路径信息")
                .font(.headline)
            
            if let description = path.pathDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if let difficulty = path.difficulty {
                    HStack {
                        Text("难度:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(difficulty)
                            .font(.subheadline)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(difficultyColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                if let createdAt = path.createdAt {
                    HStack {
                        Text("创建时间:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(createdAt, style: .date)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
            }
            
            if let tags = path.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags.components(separatedBy: ","), id: \.self) { tag in
                                Text(tag.trimmingCharacters(in: .whitespaces))
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    private var difficultyColor: Color {
        switch path.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
}

// MARK: - 进度部分

struct ProgressSection: View {
    @ObservedObject var path: LearningPath
    
    private var completedCount: Int {
        guard let problems = path.problems?.allObjects as? [Problem] else { return 0 }
        return problems.filter { $0.mastery >= 4 }.count
    }
    
    private var totalCount: Int {
        path.problems?.count ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习进度")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("整体进度")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(path.progress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: path.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                
                // Stats
                HStack {
                    StatItem(
                        title: "总题目",
                        value: "\(totalCount)",
                        color: .blue
                    )
                    
                    StatItem(
                        title: "已完成",
                        value: "\(completedCount)",
                        color: .green
                    )
                    
                    StatItem(
                        title: "进行中",
                        value: "\(totalCount - completedCount)",
                        color: .orange
                    )
                }
            }
        }
        .cardStyle()
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 题目部分

struct ProblemsSection: View {
    let problems: [Problem]
    let onAddProblems: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("路径题目")
                    .font(.headline)
                
                Spacer()
                
                Button("添加题目") {
                    onAddProblems()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            if problems.isEmpty {
                EmptyStateView(
                    title: "暂无题目",
                    subtitle: "添加一些题目到这个学习路径",
                    action: onAddProblems,
                    actionLabel: "添加题目"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(problems, id: \.id) { problem in
                        PathProblemRow(problem: problem)
                    }
                }
            }
        }
    }
}

struct PathProblemRow: View {
    @ObservedObject var problem: Problem
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var pathManager = LearningPathManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(problem.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if let algorithmType = problem.algorithmType {
                        Text(algorithmType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if let dataStructure = problem.dataStructure {
                        Text(dataStructure)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text(problem.difficulty ?? "未知")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Mastery indicator
                HStack {
                    Text("掌握度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(problem.mastery)/5")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(masteryColor)
                }
                
                // Remove button
                Button("移除") {
                    if let path = problem.learningPath {
                        _ = pathManager.removeProblemFromPath(problem)
                        pathManager.refreshPaths()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch problem.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
    
    private var masteryColor: Color {
        switch problem.mastery {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .green
        default: return .gray
        }
    }
}

// MARK: - 推荐题目部分

struct RecommendedProblemsSection: View {
    let problems: [Problem]
    let path: LearningPath
    let onAdd: (Problem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("推荐题目")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(problems.prefix(6), id: \.id) { problem in
                    RecommendedProblemCard(problem: problem) {
                        onAdd(problem)
                    }
                }
            }
        }
    }
}

struct RecommendedProblemCard: View {
    @ObservedObject var problem: Problem
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(problem.title ?? "Untitled")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        if let algorithmType = problem.algorithmType {
                            Text(algorithmType)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(3)
                        }
                        
                        Text(problem.difficulty ?? "未知")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(difficultyColor.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
                
                Button("添加") {
                    onAdd()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            if let source = problem.source {
                Text(source)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch problem.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
}

// MARK: - 添加题目到路径视图

struct AddProblemsToPathView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var path: LearningPath
    let recommendedProblems: [Problem]
    @ObservedObject private var pathManager = LearningPathManager.shared
    @State private var searchText = ""
    @State private var selectedProblems: Set<UUID> = []
    
    private var availableProblems: [Problem] {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        
        // 排除已经在路径中的题目
        let existingProblemIDs = path.problems?.compactMap { ($0 as? Problem)?.id } ?? []
        if !existingProblemIDs.isEmpty {
            request.predicate = NSPredicate(format: "NOT (id IN %@)", existingProblemIDs)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Problem.title, ascending: true)
        ]
        
        do {
            let allProblems = try viewContext.fetch(request)
            
            if searchText.isEmpty {
                return recommendedProblems + allProblems.filter { !recommendedProblems.contains($0) }
            } else {
                return allProblems.filter { problem in
                    (problem.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    (problem.algorithmType?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    (problem.dataStructure?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        } catch {
            print("Error fetching problems: \(error)")
            return []
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加题目到路径")
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
            
            // Content
            VStack(spacing: 16) {
                // Search
                HStack {
                    TextField("搜索题目...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("已选择 \(selectedProblems.count) 个")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Selected problems
                if !selectedProblems.isEmpty {
                    SelectedProblemsBar(
                        count: selectedProblems.count,
                        onClear: { selectedProblems.removeAll() }
                    )
                }
                
                // Problems list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(availableProblems, id: \.id) { problem in
                            ProblemSelectionRow(
                                problem: problem,
                                isSelected: selectedProblems.contains(problem.id!),
                                onToggle: {
                                    if selectedProblems.contains(problem.id!) {
                                        selectedProblems.remove(problem.id!)
                                    } else {
                                        selectedProblems.insert(problem.id!)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("添加选择的题目 (\(selectedProblems.count))") {
                    addSelectedProblems()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(selectedProblems.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(selectedProblems.isEmpty)
            }
            .padding()
        }
        .frame(width: 700, height: 600)
    }
    
    private func addSelectedProblems() {
        for problemID in selectedProblems {
            let request: NSFetchRequest<Problem> = Problem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", problemID as NSUUID)
            
            do {
                if let problem = try viewContext.fetch(request).first {
                    _ = pathManager.addProblemToPath(problem, to: path)
                }
            } catch {
                print("Error fetching problem: \(error)")
            }
        }
        
        pathManager.refreshPaths()
        dismiss()
    }
}

struct ProblemSelectionRow: View {
    @ObservedObject var problem: Problem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(problem.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if let algorithmType = problem.algorithmType {
                        Text(algorithmType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if let dataStructure = problem.dataStructure {
                        Text(dataStructure)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text(problem.difficulty ?? "未知")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            if recommendedProblems.contains(problem) {
                Text("推荐")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch problem.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
    
    // This would be populated with the recommended problems
    private var recommendedProblems: [Problem] {
        []
    }
}

struct SelectedProblemsBar: View {
    let count: Int
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Text("已选择 \(count) 个题目")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("清空选择") {
                onClear()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    LearningPathDetailView(path: {
        let context = PersistenceController.preview.container.viewContext
        let path = LearningPath(context: context)
        path.id = UUID()
        path.name = "算法基础入门"
        path.pathDescription = "适合初学者的算法基础知识学习路径"
        path.difficulty = "简单"
        path.progress = 0.3
        path.createdAt = Date()
        return path
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
