import SwiftUI
import CoreData

struct RecommendationDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var recommendationEngine = RecommendationEngine.shared
    @ObservedObject private var searchEngine = EnhancedSearchEngine.shared
    @State private var selectedTab = "smart"
    @State private var selectedProblem: Problem?
    @State private var showingProblemDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("智能推荐")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("基于您的学习情况智能推荐题目")
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
            
            // Tab Navigation
            HStack(spacing: 0) {
                TabButton(
                    title: "智能推荐",
                    icon: "sparkles",
                    isSelected: selectedTab == "smart"
                ) {
                    selectedTab = "smart"
                }
                
                TabButton(
                    title: "相似题目",
                    icon: "doc.on.doc",
                    isSelected: selectedTab == "similar"
                ) {
                    selectedTab = "similar"
                }
                
                TabButton(
                    title: "弱点分析",
                    icon: "exclamationmark.triangle",
                    isSelected: selectedTab == "weakness"
                ) {
                    selectedTab = "weakness"
                }
                
                TabButton(
                    title: "学习路径",
                    icon: "map",
                    isSelected: selectedTab == "path"
                ) {
                    selectedTab = "path"
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if selectedTab == "smart" {
                        SmartRecommendationsView(
                            recommendations: recommendationEngine.getSmartRecommendations(),
                            onSelectProblem: { problem in
                                selectedProblem = problem
                                showingProblemDetail = true
                            }
                        )
                    } else if selectedTab == "similar" {
                        SimilarProblemsView(
                            onSelectProblem: { problem in
                                selectedProblem = problem
                                showingProblemDetail = true
                            }
                        )
                    } else if selectedTab == "weakness" {
                        WeaknessAnalysisView(
                            onSelectProblem: { problem in
                                selectedProblem = problem
                                showingProblemDetail = true
                            }
                        )
                    } else if selectedTab == "path" {
                        LearningPathRecommendationsView(
                            onSelectProblem: { problem in
                                selectedProblem = problem
                                showingProblemDetail = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 900, height: 700)
        .onAppear {
            // Setup is handled by the shared instances
        }
        .sheet(isPresented: $showingProblemDetail) {
            if let problem = selectedProblem {
                ProblemDetailView(problem: problem)
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Smart Recommendations View

struct SmartRecommendationsView: View {
    let recommendations: [RecommendationResult]
    let onSelectProblem: (Problem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("智能推荐")
                .font(.headline)
            
            if recommendations.isEmpty {
                EmptyStateView(
                    title: "暂无推荐",
                    subtitle: "请先添加一些题目以获取智能推荐",
                    action: {},
                    actionLabel: ""
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(recommendations.prefix(6), id: \.problem.id) { recommendation in
                        RecommendationCard(
                            recommendation: recommendation,
                            onSelect: {
                                onSelectProblem(recommendation.problem)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: RecommendationResult
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.problem.title ?? "Untitled")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if let algorithmType = recommendation.problem.algorithmType {
                            Text(algorithmType)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Text(recommendation.problem.difficulty ?? "未知")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(difficultyColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Recommendation score
                    HStack {
                        Text("推荐度")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.0f", recommendation.score * 100))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(recommendationColor)
                    }
                    
                    // Reason
                    Text(recommendation.reason)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            HStack {
                Spacer()
                
                Button("查看详情") {
                    onSelect()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch recommendation.problem.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
    
    private var recommendationColor: Color {
        switch recommendation.score {
        case 0.8...1.0: return .green
        case 0.6...0.8: return .blue
        case 0.4...0.6: return .orange
        default: return .gray
        }
    }
}

// MARK: - Similar Problems View

struct SimilarProblemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @State private var selectedProblem: Problem?
    @State private var similarProblems: [Problem] = []
    
    let onSelectProblem: (Problem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("相似题目推荐")
                .font(.headline)
            
            // Problem selector
            HStack {
                Text("选择题目:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Menu(selectedProblem?.title ?? "请选择题目") {
                    ForEach(recommendationEngine.getAllProblems(), id: \.id) { problem in
                        Button(problem.title ?? "Untitled") {
                            selectedProblem = problem
                            similarProblems = recommendationEngine.getSimilarProblems(to: problem)
                        }
                    }
                }
                
                Spacer()
            }
            
            if similarProblems.isEmpty {
                EmptyStateView(
                    title: "请选择题目",
                    subtitle: "选择一个题目查看相似推荐",
                    action: {},
                    actionLabel: ""
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(similarProblems.prefix(4), id: \.id) { problem in
                        SimilarProblemCard(problem: problem) {
                            onSelectProblem(problem)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Setup is handled by the shared instances
        }
    }
}

struct SimilarProblemCard: View {
    @ObservedObject var problem: Problem
    let onSelect: () -> Void
    
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
                
                Button("查看") {
                    onSelect()
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

// MARK: - Weakness Analysis View

struct WeaknessAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @State private var weaknessAreas: [WeaknessArea] = []
    
    let onSelectProblem: (Problem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("弱点分析")
                .font(.headline)
            
            if weaknessAreas.isEmpty {
                EmptyStateView(
                    title: "分析中...",
                    subtitle: "正在分析您的学习弱点",
                    action: {},
                    actionLabel: ""
                )
            } else {
                ForEach(weaknessAreas, id: \.category) { weakness in
                    WeaknessCard(
                        weakness: weakness,
                        onSelectProblem: onSelectProblem
                    )
                }
            }
        }
        .onAppear {
            weaknessAreas = recommendationEngine.analyzeWeaknessAreas()
        }
    }
}

struct WeaknessCard: View {
    let weakness: WeaknessArea
    let onSelectProblem: (Problem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weakness.category)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("严重程度: \(String(format: "%.1f", weakness.severity * 5))/5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(weakness.affectedProblems) 个题目")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("建议练习")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            // Suggested actions
            LazyVStack(spacing: 8) {
                ForEach(weakness.suggestedActions, id: \.self) { action in
                    HStack {
                        Text(action)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Image(systemName: "lightbulb")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Learning Path Recommendations View

struct LearningPathRecommendationsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var pathManager = LearningPathManager.shared
    @State private var recommendedPaths: [LearningPathTemplate] = []
    
    let onSelectProblem: (Problem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习路径推荐")
                .font(.headline)
            
            LazyVStack(spacing: 16) {
                ForEach(recommendedPaths, id: \.name) { path in
                    PathRecommendationCard(path: path)
                }
            }
        }
        .onAppear {
            recommendedPaths = pathManager.generateRecommendedPaths()
        }
    }
}

struct PathRecommendationCard: View {
    let path: LearningPathTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(path.pathDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(path.difficulty)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text("\(path.estimatedDuration) 天")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(path.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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

#Preview {
    RecommendationDashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
