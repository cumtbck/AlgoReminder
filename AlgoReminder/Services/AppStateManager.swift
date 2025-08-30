import SwiftUI
import CoreData
import Combine

// MARK: - 应用状态管理
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    // MARK: - 状态枚举
    enum AppState {
        case idle
        case loading
        case error(Error)
        case ready
    }
    
    // MARK: - 发布的状态属性
    @Published var currentAppState: AppState = .idle
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date = Date()
    
    // MARK: - 核心数据状态
    @Published var problems: [Problem] = []
    @Published var reviews: [ReviewPlan] = []
    @Published var notes: [Note] = []
    @Published var learningPaths: [LearningPath] = []
    
    // MARK: - UI状态
    @Published var selectedProblem: Problem?
    @Published var selectedReview: ReviewPlan?
    @Published var selectedNote: Note?
    @Published var selectedLearningPath: LearningPath?
    
    @Published var searchText: String = ""
    @Published var searchFilters: SearchFilters = SearchFilters()
    @Published var searchResults: [SearchResult] = []
    
    @Published var isSearchActive: Bool = false
    @Published var isShowingAddProblem: Bool = false
    @Published var isShowingAddNote: Bool = false
    @Published var isShowingReview: Bool = false
    
    // MARK: - 统计状态
    @Published var todayReviewCount: Int = 0
    @Published var overdueReviewCount: Int = 0
    @Published var totalProblemCount: Int = 0
    @Published var averageMastery: Float = 0.0
    
    // MARK: - 依赖注入
    private let container = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
        loadData()
    }
    
    // MARK: - 数据绑定
    
    private func setupBindings() {
        // 监听Core Data变化
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .compactMap { $0.object as? NSManagedObjectContext }
            .sink { [weak self] context in
                self?.handleContextSave(context: context)
            }
            .store(in: &cancellables)
        
        // 监听复习完成
        NotificationCenter.default.publisher(for: Notification.Name("ReviewCompleted"))
            .sink { [weak self] _ in
                self?.updateReviewStatistics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        currentAppState = .loading
        isLoading = true
        
        UnifiedErrorHandler.shared.safeExecuteAsync(
            {
                let context = self.container.persistenceController.container.viewContext
                
                // 并行加载各种数据
                let problems = self.loadProblems(context: context)
                let reviews = self.loadReviews(context: context)
                let notes = self.loadNotes(context: context)
                let learningPaths = self.loadLearningPaths(context: context)
                
                DispatchQueue.main.async {
                    self.problems = problems
                    self.reviews = reviews
                    self.notes = notes
                    self.learningPaths = learningPaths
                    
                    self.updateStatistics()
                    self.currentAppState = .ready
                    self.isLoading = false
                    self.lastUpdated = Date()
                }
            },
            context: "Loading app data",
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // 数据已在主线程更新
                    case .failure(let error):
                        self?.handleError(error)
                    }
                }
            }
        )
    }
    
    // MARK: - 数据更新
    
    func refreshData() {
        loadData()
    }
    
    func addProblem(_ problem: Problem) {
        UnifiedErrorHandler.shared.safeExecuteAsync(
            {
                let context = self.container.persistenceController.container.viewContext
                context.insert(problem)
                try context.save()
                
                DispatchQueue.main.async {
                    self.problems.append(problem)
                    self.updateStatistics()
                    self.selectedProblem = problem
                }
            },
            context: "Adding problem",
            completion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.handleError(error)
                }
            }
        )
    }
    
    func deleteProblem(_ problem: Problem) {
        UnifiedErrorHandler.shared.safeExecuteAsync(
            {
                let context = self.container.persistenceController.container.viewContext
                context.delete(problem)
                try context.save()
                
                DispatchQueue.main.async {
                    self.problems.removeAll { $0.id == problem.id }
                    if self.selectedProblem?.id == problem.id {
                        self.selectedProblem = nil
                    }
                    self.updateStatistics()
                }
            },
            context: "Deleting problem",
            completion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.handleError(error)
                }
            }
        )
    }
    
    func updateProblem(_ problem: Problem) {
        UnifiedErrorHandler.shared.safeExecuteAsync(
            {
                let context = self.container.persistenceController.container.viewContext
                try context.save()
                
                DispatchQueue.main.async {
                    if let index = self.problems.firstIndex(where: { $0.id == problem.id }) {
                        self.problems[index] = problem
                    }
                    self.updateStatistics()
                }
            },
            context: "Updating problem",
            completion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.handleError(error)
                }
            }
        )
    }
    
    // MARK: - 搜索功能
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearchActive = true
        
        UnifiedErrorHandler.shared.safeExecuteAsync(
            {
                let context = self.container.persistenceController.container.viewContext
                let searchEngine = self.container.semanticSearchEngine
                
                let results = searchEngine.search(
                    query: self.searchText,
                    filters: self.searchFilters,
                    context: context,
                    limit: 50
                )
                
                DispatchQueue.main.async {
                    self.searchResults = results
                    self.isSearchActive = false
                }
            },
            context: "Performing search",
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isSearchActive = false
                    if case .failure(let error) = result {
                        self?.handleError(error)
                    }
                }
            }
        )
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        searchFilters = SearchFilters()
    }
    
    // MARK: - 复习管理
    
    func completeReview(_ review: ReviewPlan, score: Int) {
        UnifiedErrorHandler.shared.safeExecuteAsync(
            {
                let context = self.container.persistenceController.container.viewContext
                let scheduler = self.container.spacedRepetitionScheduler
                
                _ = scheduler.completeReview(
                    reviewPlan: review,
                    score: score,
                    confidence: .medium,
                    timeSpent: 0,
                    context: context
                )
                
                DispatchQueue.main.async {
                    self.updateReviewStatistics()
                    self.selectedReview = nil
                    
                    // 通知复习完成
                    NotificationCenter.default.post(
                        name: Notification.Name("ReviewCompleted"),
                        object: nil
                    )
                }
            },
            context: "Completing review",
            completion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.handleError(error)
                }
            }
        )
    }
    
    // MARK: - 状态管理
    
    private func handleError(_ error: Error) {
        let wrappedError = UnifiedErrorHandler.shared.wrapCoreDataError(error, context: "App State Manager")
        UnifiedErrorHandler.shared.handle(wrappedError, context: "App State Manager")
        
        currentAppState = .error(wrappedError)
        errorMessage = wrappedError.localizedDescription
        isLoading = false
        
        // 3秒后自动清除错误状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if case .error = self.currentAppState {
                self.currentAppState = .ready
                self.errorMessage = nil
            }
        }
    }
    
    private func handleContextSave(context: NSManagedObjectContext) {
        // 重新加载数据以保持同步
        loadData()
    }
    
    // MARK: - 统计更新
    
    private func updateStatistics() {
        updateReviewStatistics()
        updateProblemStatistics()
    }
    
    private func updateReviewStatistics() {
        let context = container.persistenceController.container.viewContext
        let scheduler = container.spacedRepetitionScheduler
        
        todayReviewCount = scheduler.getTodayReviews(context: context).count
        overdueReviewCount = scheduler.getOverdueReviews(context: context).count
    }
    
    private func updateProblemStatistics() {
        totalProblemCount = problems.count
        
        if !problems.isEmpty {
            let totalMastery = problems.reduce(0) { $0 + Int($1.mastery) }
            averageMastery = Float(totalMastery) / Float(problems.count)
        } else {
            averageMastery = 0.0
        }
    }
    
    // MARK: - 数据加载辅助方法
    
    private func loadProblems(context: NSManagedObjectContext) -> [Problem] {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Problem.updatedAt, ascending: false)
        ]
        
        return (try? context.fetch(request)) ?? []
    }
    
    private func loadReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        let request: NSFetchRequest<ReviewPlan> = ReviewPlan.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)
        ]
        
        return (try? context.fetch(request)) ?? []
    }
    
    private func loadNotes(context: NSManagedObjectContext) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)
        ]
        
        return (try? context.fetch(request)) ?? []
    }
    
    private func loadLearningPaths(context: NSManagedObjectContext) -> [LearningPath] {
        let request: NSFetchRequest<LearningPath> = LearningPath.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \LearningPath.createdAt, ascending: false)
        ]
        
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - 状态重置
    
    func resetState() {
        problems = []
        reviews = []
        notes = []
        learningPaths = []
        
        selectedProblem = nil
        selectedReview = nil
        selectedNote = nil
        selectedLearningPath = nil
        
        searchText = ""
        searchResults = []
        searchFilters = SearchFilters()
        
        isSearchActive = false
        isShowingAddProblem = false
        isShowingAddNote = false
        isShowingReview = false
        
        todayReviewCount = 0
        overdueReviewCount = 0
        totalProblemCount = 0
        averageMastery = 0.0
        
        errorMessage = nil
        currentAppState = .idle
        
        loadData()
    }
}

// MARK: - 环境值扩展

struct AppStateManagerKey: EnvironmentKey {
    static let defaultValue = AppStateManager.shared
}

extension EnvironmentValues {
    var appStateManager: AppStateManager {
        get { self[AppStateManagerKey.self] }
        set { self[AppStateManagerKey.self] = newValue }
    }
}

// MARK: - 便利的视图修饰器

extension View {
    func withAppState() -> some View {
        self.environment(\.appStateManager, AppStateManager.shared)
    }
    
    func onAppStateChange(_ action: @escaping (AppStateManager.AppState) -> Void) -> some View {
        self.onReceive(AppStateManager.shared.$currentAppState) { state in
            action(state)
        }
    }
    
    func isLoading(_ isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(width: 100, height: 100)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
            }
        )
    }
}

// MARK: - 状态视图组件

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("发生错误")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let retryAction = retryAction {
                Button("重试") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - 使用示例

struct AppStateUsageExample: View {
    @Environment(\.appStateManager) private var appState
    
    var body: some View {
        VStack {
            switch appState.currentAppState {
            case .idle:
                Text("准备中...")
            case .loading:
                LoadingView(message: "正在加载数据...")
            case .error(let error):
                ErrorView(error: error) {
                    appState.refreshData()
                }
            case .ready:
                ContentView()
            }
        }
        .onAppStateChange { state in
            print("App state changed to: \(state)")
        }
    }
}