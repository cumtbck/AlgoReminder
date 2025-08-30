import SwiftUI
import CoreData

struct LearningPathManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pathManager = LearningPathManager.shared
    @State private var showingCreatePath = false
    @State private var showingTemplateSelection = false
    @State private var selectedTemplate: LearningPathTemplate?
    @State private var showingPathDetail = false
    @State private var selectedPath: LearningPath?
    @State private var showingAddProblems = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("学习路径管理")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("从模板创建") {
                    showingTemplateSelection = true
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("创建路径") {
                    showingCreatePath = true
                }
                .buttonStyle(PrimaryButtonStyle())
                
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
                VStack(spacing: 24) {
                    // Statistics
                    PathStatsView(stats: pathManager.getPathStats())
                    
                    // Active Path
                    if let activePath = pathManager.activePath {
                        ActivePathCard(path: activePath) {
                            selectedPath = activePath
                            showingPathDetail = true
                        }
                    }
                    
                    // All Paths
                    VStack(alignment: .leading, spacing: 16) {
                        Text("所有学习路径")
                            .font(.headline)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(pathManager.learningPaths, id: \.id) { path in
                                LearningPathCard(path: path, isActive: pathManager.activePath?.id == path.id) {
                                    pathManager.setActivePath(path)
                                    pathManager.refreshPaths()
                                } onEdit: {
                                    selectedPath = path
                                    showingPathDetail = true
                                } onDelete: {
                                    _ = pathManager.deleteLearningPath(path)
                                    pathManager.refreshPaths()
                                }
                            }
                        }
                    }
                    
                    if pathManager.learningPaths.isEmpty {
                        EmptyStateView(
                            title: "暂无学习路径",
                            subtitle: "创建您的第一个学习路径开始系统化学习",
                            action: {
                                showingTemplateSelection = true
                            },
                            actionLabel: "从模板开始"
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
        .sheet(isPresented: $showingCreatePath) {
            CreateLearningPathView()
        }
        .sheet(isPresented: $showingTemplateSelection) {
            TemplateSelectionView { template in
                selectedTemplate = template
                showingCreatePath = true
            }
        }
        .sheet(isPresented: $showingPathDetail) {
            if let path = selectedPath {
                LearningPathDetailView(path: path)
            }
        }
    }
}

// MARK: - 统计卡片

struct PathStatsView: View {
    let stats: LearningPathStats
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "总路径数",
                value: "\(stats.totalPaths)",
                color: .blue,
                icon: "list.bullet"
            )
            
            StatCard(
                title: "活跃路径",
                value: "\(stats.activePaths)",
                color: .green,
                icon: "play.fill"
            )
            
            StatCard(
                title: "完成路径",
                value: "\(stats.completedPaths)",
                color: .purple,
                icon: "checkmark.circle.fill"
            )
            
            StatCard(
                title: "平均进度",
                value: "\(Int(stats.averageProgress * 100))%",
                color: .orange,
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - 活跃路径卡片

struct ActivePathCard: View {
    let path: LearningPath
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前学习路径")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(path.name ?? "Untitled")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("查看详情") {
                    onTap()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(path.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: path.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            // Path info
            HStack {
                Label("\(path.problems?.count ?? 0) 个题目", systemImage: "book.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let difficulty = path.difficulty {
                    Text(difficulty)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .cardStyle(backgroundColor: Color.blue.opacity(0.1))
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

// MARK: - 学习路径卡片

struct LearningPathCard: View {
    @ObservedObject var path: LearningPath
    let isActive: Bool
    let onSetActive: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(path.name ?? "Untitled")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isActive {
                            Text("活跃")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    if let description = path.pathDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(isActive ? "当前路径" : "设为活跃") {
                        onSetActive()
                    }
                    .disabled(isActive)
                    .buttonStyle(ActivePathButtonStyle(isActive: isActive))
                    
                    HStack {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(IconButtonStyle())
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(IconButtonStyle(color: .red))
                    }
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(path.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: path.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: isActive ? .blue : .gray))
            }
            
            // Path stats
            HStack {
                Label("\(path.problems?.count ?? 0) 个题目", systemImage: "book.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let difficulty = path.difficulty {
                    Text(difficulty)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if let createdAt = path.createdAt {
                    Text("创建于 \(createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

// MARK: - 创建学习路径视图

struct CreateLearningPathView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pathManager = LearningPathManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var difficulty = "中等"
    @State private var tags = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("创建学习路径")
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
                        Text("路径名称 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入学习路径名称", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("路径描述 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("难度等级 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("难度", selection: $difficulty) {
                            Text("简单").tag("简单")
                            Text("中等").tag("中等")
                            Text("困难").tag("困难")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("用逗号分隔，如：基础,算法,数据结构", text: $tags)
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
                
                Button("创建") {
                    createPath()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(name.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func createPath() {
        guard !name.isEmpty else {
            alertMessage = "请输入路径名称"
            showingAlert = true
            return
        }
        
        guard !description.isEmpty else {
            alertMessage = "请输入路径描述"
            showingAlert = true
            return
        }
        
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        if let path = pathManager.createLearningPath(
            name: name,
            description: description,
            difficulty: difficulty,
            tags: tagArray
        ) {
            dismiss()
        } else {
            alertMessage = "创建失败"
            showingAlert = true
        }
    }
}

// MARK: - 模板选择视图

struct TemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelectTemplate: (LearningPathTemplate) -> Void
    
    private let templates = LearningPathManager.shared.generateRecommendedPaths()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("选择学习路径模板")
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
            
            // Templates
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(templates.indices, id: \.self) { index in
                        let template = templates[index]
                        TemplateCard(template: template) {
                            onSelectTemplate(template)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
    }
}

struct TemplateCard: View {
    let template: LearningPathTemplate
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(template.pathDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("使用模板") {
                        onSelect()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            
            // Template info
            HStack {
                Label("\(template.estimatedDuration) 天", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(template.difficulty)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(difficultyColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(template.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .cardStyle()
    }
    
    private var difficultyColor: Color {
        switch template.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
}

// MARK: - 按钮样式

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = .blue) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ActivePathButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    LearningPathManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}