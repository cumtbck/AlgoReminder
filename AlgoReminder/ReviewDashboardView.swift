import SwiftUI
import CoreData

enum ReviewCategory: String, CaseIterable {
    case today = "今日复习"
    case overdue = "逾期复习"
    case thisWeek = "本周复习"
    
    var icon: String {
        switch self {
        case .today: return "calendar.badge.clock"
        case .overdue: return "exclamationmark.triangle"
        case .thisWeek: return "calendar"
        }
    }
    
    var color: Color {
        switch self {
        case .today: return .blue
        case .overdue: return .red
        case .thisWeek: return .green
        }
    }
}

struct ReviewDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)],
        predicate: NSPredicate(format: "status == %@", "pending"),
        animation: .default)
    private var pendingReviews: FetchedResults<ReviewPlan>
    
    @State private var selectedReview: ReviewPlan?
    @State private var showingScoreSheet = false
    @State private var refreshToggle = false
    @State private var selectedCategory: ReviewCategory = .today
    
    private var todayReviews: [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return pendingReviews.filter { review in
            guard let scheduledAt = review.scheduledAt else { return false }
            return scheduledAt >= today && scheduledAt < tomorrow
        }
    }
    
    private var overdueReviews: [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return pendingReviews.filter { review in
            guard let scheduledAt = review.scheduledAt else { return false }
            return scheduledAt < today
        }
    }
    
    private var thisWeekReviews: [ReviewPlan] {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本周一的日期
        let mondayOfWeek = getStartOfWeek(from: now)
        
        // 获取本周日的日期
        let sundayOfWeek = calendar.date(byAdding: .day, value: 6, to: mondayOfWeek)!
        
        // 包含从本周一到本周日的所有待复习题目
        return pendingReviews.filter { review in
            guard let scheduledAt = review.scheduledAt else { return false }
            return scheduledAt >= mondayOfWeek && scheduledAt <= sundayOfWeek
        }.sorted { $0.scheduledAt ?? Date() < $1.scheduledAt ?? Date() }
    }
    
    // 辅助方法：获取本周一的日期
    private func getStartOfWeek(from date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)!
    }
    
    private var currentReviews: [ReviewPlan] {
        switch selectedCategory {
        case .today:
            return todayReviews
        case .overdue:
            return overdueReviews
        case .thisWeek:
            return thisWeekReviews
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("复习仪表板")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
            VStack(spacing: 0) {
                // Summary Cards
                HStack(spacing: 16) {
                    ReviewSummaryCard(
                        title: "今日复习",
                        count: todayReviews.count,
                        color: .blue,
                        icon: "calendar.badge.clock"
                    )
                    
                    ReviewSummaryCard(
                        title: "逾期复习",
                        count: overdueReviews.count,
                        color: .red,
                        icon: "exclamationmark.triangle"
                    )
                    
                    ReviewSummaryCard(
                        title: "本周复习",
                        count: thisWeekReviews.count,
                        color: .green,
                        icon: "calendar"
                    )
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Category Selector
                HStack(spacing: 0) {
                    ForEach(ReviewCategory.allCases, id: \.self) { category in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedCategory = category
                            }
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category ? 
                                category.color.opacity(0.2) : 
                                Color.clear
                            )
                            .foregroundColor(
                                selectedCategory == category ? 
                                category.color : 
                                .secondary
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if category != ReviewCategory.allCases.last {
                            Spacer()
                                .frame(width: 8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.horizontal)
                
                // Reviews List
                ScrollView {
                    VStack(spacing: 16) {
                        if !currentReviews.isEmpty {
                            ReviewSectionView(
                                title: selectedCategory.rawValue,
                                reviews: currentReviews,
                                onReviewComplete: { review in
                                    selectedReview = review
                                    showingScoreSheet = true
                                },
                                onReviewSkip: { review in
                                    ReviewScheduler.shared.skipReview(reviewPlan: review, context: viewContext)
                                    refreshAllData()
                                },
                                onReviewPostpone: { review, days in
                                    ReviewScheduler.shared.postponeReview(reviewPlan: review, days: days, context: viewContext)
                                    refreshAllData()
                                }
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                
                                Text("暂无\(selectedCategory.rawValue)任务")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("您可以添加新的题目开始学习")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 800, height: 600)
        .sheet(isPresented: $showingScoreSheet) {
            if let review = selectedReview {
                EnhancedScoreInputView(reviewPlan: review) { score in
                    completeReviewAndRefresh(review: review, score: score)
                }
            }
        }
    }
    
    // 初始化
    init() {
        // 设置默认选中类别
        _selectedCategory = State(initialValue: .today)
        
        // 注册通知监听器
        NotificationCenter.default.addObserver(forName: .reviewCompleted, object: nil, queue: .main) { [self] _ in
            refreshAllData()
        }
        
        NotificationCenter.default.addObserver(forName: .reviewSkipped, object: nil, queue: .main) { [self] _ in
            refreshAllData()
        }
    }
    
    private func completeReviewAndRefresh(review: ReviewPlan, score: Int) {
        // 检查复习日期
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let reviewDate = calendar.startOfDay(for: review.scheduledAt ?? Date())
        
        // 允许对今日和逾期的复习进行评分
        if reviewDate <= today {
            // 完成复习并创建下一次复习计划
            let nextReview = ReviewScheduler.shared.completeReview(reviewPlan: review, score: score, context: viewContext)
            
            // 更新题目信息
            if let problem = review.problem {
                problem.mastery = Int16(score)
                problem.lastPracticeAt = Date()
                problem.averageScore = calculateNewAverageScore(for: problem, newScore: score)
                problem.totalReviews += 1
            }
            
            // 如果是逾期复习，确保下一次复习安排在本周内合适位置
            if reviewDate < today && nextReview != nil {
                adjustOverdueReviewNextSchedule(nextReview!)
            }
            
            // 关闭评分页面
            showingScoreSheet = false
            selectedReview = nil
            
            // 强制刷新界面
            refreshAllData()
            
            // 更新通知
            NotificationManager.shared.updateNotificationContent()
            
            // 发送复习完成通知
            NotificationCenter.default.post(name: .reviewCompleted, object: nil)
        } else {
            // 如果是未来的复习，不允许评分
            print("只能对今日或逾期的复习进行评分")
            showingScoreSheet = false
            selectedReview = nil
        }
    }
    
    // 调整逾期复习的下次安排时间，确保在本周复习中正确排序
    private func adjustOverdueReviewNextSchedule(_ nextReview: ReviewPlan) {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本周一和本周日
        let mondayOfWeek = getStartOfWeek(from: now)
        let sundayOfWeek = calendar.date(byAdding: .day, value: 6, to: mondayOfWeek)!
        
        // 如果下一次复习时间已经在本周内，则不需要调整
        guard let scheduledAt = nextReview.scheduledAt else { return }
        
        if scheduledAt >= mondayOfWeek && scheduledAt <= sundayOfWeek {
            // 找到本周复习中合适的插入位置
            let thisWeekReviews = getThisWeekReviewsForInsertion()
            
            if let lastReview = thisWeekReviews.last, let lastTime = lastReview.scheduledAt {
                // 将新复习安排在最后一个本周复习之后，但仍在周日之前
                let newTime = calendar.date(byAdding: .minute, value: 1, to: lastTime)!
                if newTime <= sundayOfWeek {
                    nextReview.scheduledAt = newTime
                }
            }
        }
    }
    
    // 获取本周复习用于插入排序
    private func getThisWeekReviewsForInsertion() -> [ReviewPlan] {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取本周一的日期
        let mondayOfWeek = getStartOfWeek(from: now)
        
        // 获取本周日的日期
        let sundayOfWeek = calendar.date(byAdding: .day, value: 6, to: mondayOfWeek)!
        
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND scheduledAt >= %@ AND scheduledAt <= %@", 
                                     "pending", mondayOfWeek as NSDate, sundayOfWeek as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)]
        
        return (try? viewContext.fetch(request)) ?? []
    }
    
    // 强制刷新所有数据
    private func refreshAllData() {
        // 强制重新计算所有属性
        let _ = todayReviews
        let _ = overdueReviews
        let _ = thisWeekReviews
        
        // 触发UI刷新
        refreshToggle.toggle()
        
        // 保存上下文确保数据持久化
        do {
            try viewContext.save()
        } catch {
            print("Error saving context during refresh: \(error)")
        }
    }
    
    // 计算新的平均分数
    private func calculateNewAverageScore(for problem: Problem, newScore: Int) -> Float {
        let totalReviews = Int(problem.totalReviews)
        let currentAverage = problem.averageScore
        
        if totalReviews == 0 {
            return Float(newScore)
        } else {
            return (currentAverage * Float(totalReviews) + Float(newScore)) / Float(totalReviews + 1)
        }
    }
}

struct ReviewSummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text("\(count)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

struct ReviewSectionView: View {
    let title: String
    let reviews: [ReviewPlan]
    let onReviewComplete: (ReviewPlan) -> Void
    let onReviewSkip: (ReviewPlan) -> Void
    let onReviewPostpone: (ReviewPlan, Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(reviews, id: \.id) { review in
                ReviewCard(review: review)
                    .padding(.horizontal)
            }
        }
    }
}

struct EnhancedScoreInputView: View {
    @Environment(\.dismiss) private var dismiss
    let reviewPlan: ReviewPlan
    let onScoreSelected: (Int) -> Void
    
    @State private var selectedScore: Int = 3
    @State private var showConfirmAnimation = false
    
    private let scoreDescriptions = [
        0: ("完全不会，需要重新学习", Color.red),
        1: ("基本不会，需要重点复习", Color.orange),
        2: ("有点印象，但需要巩固", Color.yellow),
        3: ("基本掌握，但不够熟练", Color.blue),
        4: ("掌握较好，偶有错误", Color.green),
        5: ("完全掌握，非常熟练", Color.mint)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("复习评分")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("第 \(Int(reviewPlan.intervalLevel) + 1) 次复习")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
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
            VStack(spacing: 24) {
                // Problem info
                VStack(spacing: 8) {
                    Text(reviewPlan.problem?.title ?? "未知题目")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    HStack {
                        Text(reviewPlan.problem?.source ?? "Custom")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        if let algorithmType = reviewPlan.problem?.algorithmType {
                            Text(algorithmType)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Text(reviewPlan.problem?.difficulty ?? "未知")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(difficultyColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                // Score buttons
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(0..<6, id: \.self) { score in
                        ScoreButton(
                            score: score,
                            isSelected: selectedScore == score,
                            showAnimation: showConfirmAnimation && selectedScore == score,
                            onTap: {
                                withAnimation(.spring()) {
                                    selectedScore = score
                                    showConfirmAnimation = true
                                    
                                    // 自动保存并返回
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onScoreSelected(score)
                                        
                                        // 自动关闭评分页面
                                        dismiss()
                                        
                                        // 发送复习完成通知，更新UI
                                        NotificationCenter.default.post(name: .reviewCompleted, object: nil)
                                    }
                                }
                            }
                        )
                    }
                }
                
                // Current selection description
                if selectedScore >= 0 {
                    Text(scoreDescriptions[selectedScore]?.0 ?? "")
                        .font(.subheadline)
                        .foregroundColor(scoreColor(selectedScore))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            selectedScore = 3
            showConfirmAnimation = false
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        return scoreDescriptions[score]?.1 ?? .gray
    }
    
    private func scoreIcon(_ score: Int) -> String {
        switch score {
        case 0: return "xmark.circle"
        case 1: return "hand.thumbsdown"
        case 2: return "questionmark.circle"
        case 3: return "equal.circle"
        case 4: return "hand.thumbsup"
        case 5: return "checkmark.circle"
        default: return "circle"
        }
    }
    
    private var difficultyColor: Color {
        switch reviewPlan.problem?.difficulty ?? "" {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
}

struct ScoreButton: View {
    let score: Int
    let isSelected: Bool
    let showAnimation: Bool
    let onTap: () -> Void
    
    private let scoreDescriptions = [
        0: ("完全不会，需要重新学习", Color.red),
        1: ("基本不会，需要重点复习", Color.orange),
        2: ("有点印象，但需要巩固", Color.yellow),
        3: ("基本掌握，但不够熟练", Color.blue),
        4: ("掌握较好，偶有错误", Color.green),
        5: ("完全掌握，非常熟练", Color.mint)
    ]
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: scoreIcon(score))
                    .font(.system(size: 24))
                    .foregroundColor(scoreColor(score))
                
                Text("\(score)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(score))
                
                Text(scoreDescriptions[score]?.0 ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? scoreColor(score).opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? scoreColor(score) : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(showAnimation ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .hoverEffect(.highlight)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        return scoreDescriptions[score]?.1 ?? .gray
    }
    
    private func scoreIcon(_ score: Int) -> String {
        switch score {
        case 0: return "xmark.circle"
        case 1: return "hand.thumbsdown"
        case 2: return "questionmark.circle"
        case 3: return "equal.circle"
        case 4: return "hand.thumbsup"
        case 5: return "checkmark.circle"
        default: return "circle"
        }
    }
}

#Preview {
    ReviewDashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}