import SwiftUI

// MARK: - 通知名称扩展
extension Notification.Name {
    static let reviewCompleted = Notification.Name("reviewCompleted")
    static let reviewSkipped = Notification.Name("reviewSkipped")
}

// MARK: - 通知节流管理器
class NotificationThrottler {
    static let shared = NotificationThrottler()
    
    private var lastNotificationTimes: [String: Date] = [:]
    private let throttleInterval: TimeInterval = 0.5
    
    private init() {}
    
    func shouldPostNotification(named name: Notification.Name) -> Bool {
        let key = name.rawValue
        let now = Date()
        
        if let lastTime = lastNotificationTimes[key] {
            let timeSinceLast = now.timeIntervalSince(lastTime)
            if timeSinceLast < throttleInterval {
                return false
            }
        }
        
        lastNotificationTimes[key] = now
        return true
    }
    
    func postNotificationThrottled(name: Notification.Name, object: Any? = nil) {
        if shouldPostNotification(named: name) {
            NotificationCenter.default.post(name: name, object: object)
        }
    }
}

// MARK: - 通用卡片样式
struct CardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 4,
        backgroundColor: Color = Color(NSColor.controlBackgroundColor),
        borderColor: Color = Color.clear,
        borderWidth: CGFloat = 0
    ) -> some View {
        self.modifier(CardModifier(
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            borderWidth: borderWidth
        ))
    }
    
    func modernCardStyle(
        isSelected: Bool = false,
        accentColor: Color = .blue
    ) -> some View {
        self.modifier(CardModifier(
            cornerRadius: 16,
            shadowRadius: isSelected ? 8 : 4,
            backgroundColor: isSelected ? accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor),
            borderColor: isSelected ? accentColor : Color.clear,
            borderWidth: isSelected ? 2 : 0
        ))
    }

    /// 根据全局设置的卡片样式自动适配。
    func appCardStyle(isSelected: Bool = false) -> some View {
        self.modifier(AppCardStyleModifier(isSelected: isSelected))
    }
}

// MARK: - 动态样式修饰符
struct AppCardStyleModifier: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    let isSelected: Bool

    func body(content: Content) -> some View {
        switch settings.cardStyle {
        case .modern:
            content.modernCardStyle(isSelected: isSelected, accentColor: settings.accentColor)
        case .classic:
            content.cardStyle(cornerRadius: 12,
                              shadowRadius: 2,
                              backgroundColor: Color(NSColor.controlBackgroundColor),
                              borderColor: settings.accentColor.opacity(0.4),
                              borderWidth: 1)
        case .compact:
            content
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(settings.accentColor.opacity(0.25), lineWidth: 1))
                .cornerRadius(8)
        }
    }
}

// MARK: - 题目卡片组件
struct ProblemCard: View {
    @ObservedObject var problem: Problem
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingNoteViewer = false
    @State private var showingDetail = false
    @State private var showingDeleteAlert = false
    
    private var nextReview: ReviewPlan? {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "problem == %@ AND status == %@", problem, "pending")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)]
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
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
        VStack(alignment: .leading, spacing: 16) {
            // 标题和基本信息
            cardHeader
            
            // 标签
            if let tags = problem.skillTags, !tags.isEmpty {
                tagsSection
            }
            
            // 操作按钮
            actionButtons
        }
    .appCardStyle()
        .onHover { isHovered in
            // 可以添加悬停效果
        }
        .sheet(isPresented: $showingNoteViewer) {
            NoteViewerView(problem: problem)
        }
        .sheet(isPresented: $showingDetail) {
            ProblemDetailView(problem: problem)
        }
        .alert("删除题目", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteProblem()
            }
        } message: {
            Text("确定要删除题目\"\(problem.title ?? "Untitled")\"吗？此操作不可撤销。")
        }
    }
    
    private var cardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(problem.title ?? "Untitled")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let url = problem.url, !url.isEmpty {
                        Button(action: openURL) {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("打开题目链接")
                    }
                }
                
                HStack(spacing: 8) {
                    if problem.algorithmType != nil {
                        categoryBadge
                    }
                    
                    difficultyBadge
                    
                    sourceBadge
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                masteryBadge
                
                if let review = nextReview {
                    nextReviewBadge(review)
                }
            }
        }
    }
    
    private var categoryBadge: some View {
        Text(problem.algorithmType ?? "未分类")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.2))
            .cornerRadius(4)
    }
    
    private var difficultyBadge: some View {
        Text(problem.difficulty ?? "未知")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(difficultyColor.opacity(0.2))
            .cornerRadius(4)
    }
    
    private var sourceBadge: some View {
        Text(problem.source ?? "自定义")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
    }
    
    private var masteryBadge: some View {
        Text(masteryLevel)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private func nextReviewBadge(_ review: ReviewPlan) -> some View {
        Text(review.scheduledAt ?? Date(), style: .date)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var tagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tagsArray, id: \.self) { tag in
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
    
    private var tagsArray: [String] {
        guard let tags = problem.skillTags, !tags.isEmpty else { return [] }
        return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private var actionButtons: some View {
        HStack {
            Button(action: { showingNoteViewer = true }) {
                HStack {
                    Image(systemName: "note.text")
                    Text("笔记")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: { showingDetail = true }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("详情")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func openURL() {
        guard let urlString = problem.url, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func deleteProblem() {
        viewContext.delete(problem)
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting problem: \(error)")
        }
    }
}

// MARK: - 笔记卡片组件
struct NoteCard: View {
    @ObservedObject var note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingNoteViewer = false
    @State private var showingDeleteAlert = false
    
    private var associatedProblems: [Problem] {
        guard let problemsSet = note.problems else { return [] }
        return Array(problemsSet) as? [Problem] ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和基本信息
            noteHeader
            
            // 关联题目
            if !associatedProblems.isEmpty {
                associatedProblemsSection
            }
            
            // 操作按钮
            noteActionButtons
        }
    .appCardStyle()
        .onHover { isHovered in
            // 可以添加悬停效果
        }
        .sheet(isPresented: $showingNoteViewer) {
            NoteViewerView(problem: associatedProblems.first ?? createDummyProblem())
        }
        .alert("删除笔记", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("确定要删除笔记\"\(note.title ?? "Untitled Note")\"吗？此操作不可撤销。")
        }
    }
    
    private var noteHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title ?? "Untitled Note")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "note.text")
                        .foregroundColor(.purple)
                        .font(.caption)
                }
                
                if let importedFrom = note.importedFromURL {
                    Text("📎 \(URL(fileURLWithPath: importedFrom).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("更新于 \(note.updatedAt ?? Date(), style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(associatedProblems.count) 个关联题目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let preview = notePreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
    
    private var notePreview: String? {
        guard let markdown = note.rawMarkdown else { return nil }
        let lines = markdown.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return nonEmptyLines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var associatedProblemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关联题目")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(associatedProblems.prefix(3), id: \.id) { problem in
                        Button(action: {
                            openProblemURL(problem)
                        }) {
                            HStack(spacing: 4) {
                                if problem.url != nil {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                }
                                Text(problem.title ?? "未知题目")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(problem.url != nil ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            .foregroundColor(problem.url != nil ? .blue : .secondary)
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(problem.url == nil)
                    }
                    
                    if associatedProblems.count > 3 {
                        Text("+\(associatedProblems.count - 3)")
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
    
    private var noteActionButtons: some View {
        HStack {
            Button(action: { showingNoteViewer = true }) {
                HStack {
                    Image(systemName: "eye")
                    Text("查看")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func createDummyProblem() -> Problem {
        let problem = Problem(context: viewContext)
        problem.id = UUID()
        problem.title = "关联题目"
        problem.source = "Imported"
        problem.difficulty = "中等"
        return problem
    }
    
    private func deleteNote() {
        viewContext.delete(note)
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    private func openProblemURL(_ problem: Problem) {
        guard let urlString = problem.url, let url = URL(string: urlString) else {
            print("Invalid URL for problem: \(problem.title ?? "Unknown")")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
}

// MARK: - 复习计划卡片组件
struct ReviewCard: View {
    @ObservedObject var review: ReviewPlan
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingScoreSheet = false
    @State private var showingSkipAlert = false
    
    private var scoreColor: Color {
        switch Int(review.score) {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 复习信息
            reviewHeader
            
            // 操作按钮
            reviewActionButtons
        }
        .cardStyle(
            backgroundColor: review.status == "pending" ? Color(NSColor.controlBackgroundColor) : Color.green.opacity(0.1)
        )
        .sheet(isPresented: $showingScoreSheet) {
            ScoreInputView(review: review)
        }
        .alert("跳过复习", isPresented: $showingSkipAlert) {
            Button("取消", role: .cancel) { }
            Button("跳过", role: .destructive) {
                skipReview()
            }
        } message: {
            Text("确定要跳过本次复习吗？题目将移到今天复习列表的最底部。")
        }
    }
    
    private var reviewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(review.problem?.title ?? "未知题目")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text("第 \(Int(review.intervalLevel) + 1) 次复习")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    if review.status == "completed" {
                        Text("已复习")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    } else if isOverdueReview() {
                        Text("逾期复习")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    } else if isTodayReview() {
                        Text("今日复习")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text("待复习")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(review.scheduledAt ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if review.status == "completed" {
                    // 显示历史平均得分
                    if let problem = review.problem, problem.totalReviews > 0 {
                        Text("历史平均: \(String(format: "%.1f", problem.averageScore))")
                            .font(.subheadline)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(scoreColor.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text("评分: \(review.score)")
                            .font(.subheadline)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(scoreColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                } else {
                    // 显示历史平均分或待评分
                    if let problem = review.problem, problem.totalReviews > 0 {
                        Text("历史平均: \(String(format: "%.1f", problem.averageScore))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("待评分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var reviewActionButtons: some View {
        HStack {
            if review.status == "pending" {
                Button(action: { 
                    // 检查是否为今日或逾期复习
                    if canReview() {
                        showingScoreSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(reviewStatusText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(canReview() ? reviewActionColor : Color.gray.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canReview())
                .help(reviewHelpText)
                
                Spacer()
                
                if canSkip() {
                    Button(action: { showingSkipAlert = true }) {
                        HStack {
                            Image(systemName: "forward")
                            Text("跳过")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("将此卡片移至今日复习列表底部")
                }
            } else {
                Button(action: { showingScoreSheet = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("修改评分")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
    }
    
    // 动态状态文本和颜色
    private var reviewStatusText: String {
        if review.status == "completed" {
            return "已复习"
        } else if isTodayReview() {
            return "待评分"
        } else if isOverdueReview() {
            return "逾期复习"
        } else {
            return "待复习"
        }
    }
    
    private var reviewActionColor: Color {
        if isTodayReview() {
            return Color.green.opacity(0.2)
        } else if isOverdueReview() {
            return Color.red.opacity(0.2)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    private var reviewHelpText: String {
        if isTodayReview() {
            return "点击完成复习并进行评分"
        } else if isOverdueReview() {
            return "点击完成逾期复习"
        } else {
            return "只能对今日或逾期的复习进行评分"
        }
    }
    
    // 判断是否可以复习
    private func canReview() -> Bool {
        return isTodayReview() || isOverdueReview()
    }
    
    // 判断是否可以跳过
    private func canSkip() -> Bool {
        return isTodayReview() && review.status == "pending"
    }
    
    private func isTodayReview() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let reviewDate = calendar.startOfDay(for: review.scheduledAt ?? Date())
        return reviewDate == today
    }
    
    private func isOverdueReview() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let reviewDate = calendar.startOfDay(for: review.scheduledAt ?? Date())
        return reviewDate < today
    }
    
    private func skipReview() {
        // Move to the bottom of today's review list by setting scheduled time to late today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Find the latest scheduled time among today's reviews
        let todayReviews = getTodayReviews()
        let latestTime = todayReviews
            .compactMap { $0.scheduledAt }
            .max() ?? calendar.date(byAdding: .hour, value: 23, to: today)!
        
        // Set the skipped review to be 1 minute after the latest one
        let newScheduledTime = calendar.date(byAdding: .minute, value: 1, to: latestTime)!
        
        review.scheduledAt = newScheduledTime
        // Keep status as "pending", just move to bottom of today's list
        
        do {
            try viewContext.save()
            // 发送通知，通知仪表盘更新卡片顺序（使用节流机制）
            NotificationThrottler.shared.postNotificationThrottled(name: .reviewSkipped, object: nil)
        } catch {
            print("Error skipping review: \(error)")
        }
    }
    
    // Helper method to get all today's reviews for ordering
    private func getTodayReviews() -> [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND scheduledAt >= %@ AND scheduledAt < %@", 
                                     "pending", today as NSDate, tomorrow as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)]
        
        return (try? viewContext.fetch(request)) ?? []
    }
}

// MARK: - 评分输入组件
struct ScoreInputView: View {
    @ObservedObject var review: ReviewPlan
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedScore: Int = 3
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("复习评分")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("跳过") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("题目：\(review.problem?.title ?? "未知题目")")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("请根据您的掌握程度评分：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Score Selection
                VStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { score in
                        Button(action: { selectedScore = score }) {
                            HStack {
                                Text("\(score) 分")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text(scoreDescription(score))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if selectedScore == score {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(selectedScore == score ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("保存") {
                    saveScore()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func scoreDescription(_ score: Int) -> String {
        switch score {
        case 0: return "完全不会"
        case 1: return "基本不会"
        case 2: return "有些印象"
        case 3: return "基本掌握"
        case 4: return "掌握良好"
        case 5: return "完全掌握"
        default: return ""
        }
    }
    
    private func saveScore() {
        review.score = Int16(selectedScore)
        review.status = "completed"
        
        // Update problem mastery
        if let problem = review.problem {
            problem.mastery = Int16(selectedScore)
            problem.lastPracticeAt = Date()
            
            // Complete the review and create next plan
            ReviewScheduler.shared.completeReview(reviewPlan: review, score: selectedScore, context: viewContext)
        }
        
        do {
            try viewContext.save()
            // 自动关闭评分页面，返回到仪表盘
            dismiss()
            
            // 发送通知，通知仪表盘更新（使用节流机制）
            NotificationThrottler.shared.postNotificationThrottled(name: .reviewCompleted, object: nil)
        } catch {
            alertMessage = "保存失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ProblemCard(problem: {
            let context = PersistenceController.preview.container.viewContext
            let problem = Problem(context: context)
            problem.id = UUID()
            problem.title = "示例题目"
            problem.source = "LeetCode"
            problem.difficulty = "中等"
            problem.algorithmType = "数组"
            problem.skillTags = "数组,双指针"
            problem.mastery = 3
            return problem
        }())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        
        NoteCard(note: {
            let context = PersistenceController.preview.container.viewContext
            let note = Note(context: context)
            note.id = UUID()
            note.title = "示例笔记"
            note.rawMarkdown = "# 示例笔记\n\n这是一个示例笔记内容。"
            note.updatedAt = Date()
            return note
        }())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
    .padding()
}
