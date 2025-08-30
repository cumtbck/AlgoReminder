import Foundation
import CoreData
import SwiftUI

// MARK: - 依赖注入容器
class DependencyContainer {
    static let shared = DependencyContainer()
    
    // MARK: - 服务注册
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    // MARK: - Core Data Context
    var persistenceController: PersistenceController {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 搜索相关
    var semanticSearchEngine: SemanticSearchEngine {
        get { resolve() }
        set { register(newValue) }
    }
    
    var enhancedSearchEngine: EnhancedSearchEngine {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 复习调度
    var spacedRepetitionScheduler: SpacedRepetitionScheduler {
        get { resolve() }
        set { register(newValue) }
    }
    
    var reviewScheduler: ReviewScheduler {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 窗口管理
    var improvedWindowManager: ImprovedWindowManager {
        get { resolve() }
        set { register(newValue) }
    }
    
    var windowManager: WindowManager {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 推荐引擎
    var recommendationEngine: RecommendationEngine {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 学习路径管理
    var learningPathManager: LearningPathManager {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 通知管理
    var notificationManager: NotificationManager {
        get { resolve() }
        set { register(newValue) }
    }
    
    // MARK: - 应用配置
    var appConfig: AppConfig {
        get { resolve() }
        set { register(newValue) }
    }
    
    private init() {
        setupDefaultServices()
    }
    
    // MARK: - 依赖注入核心方法
    
    private func register<T>(_ service: T) {
        let key = String(describing: T.self)
        services[key] = service
    }
    
    private func register<T>(_ factory: @escaping () -> T) {
        let key = String(describing: T.self)
        factories[key] = factory
    }
    
    private func resolve<T>() -> T {
        let key = String(describing: T.self)
        
        // 首先检查已注册的服务
        if let service = services[key] as? T {
            return service
        }
        
        // 然后检查工厂
        if let factory = factories[key] as? () -> T {
            let service = factory()
            services[key] = service
            return service
        }
        
        // 如果都没有找到，创建默认实例
        let defaultService = createDefaultService(for: T.self)
        services[key] = defaultService
        return defaultService
    }
    
    // MARK: - 默认服务创建
    
    private func setupDefaultServices() {
        // 注册Core Data相关服务
        register { PersistenceController.shared }
        
        // 注册搜索服务
        register { SemanticSearchEngine.shared }
        register { EnhancedSearchEngine.shared }
        
        // 注册复习调度服务
        register { SpacedRepetitionScheduler.shared }
        register { ReviewScheduler.shared }
        
        // 注册窗口管理服务
        register { ImprovedWindowManager.shared }
        register { WindowManager.shared }
        
        // 注册推荐引擎
        register { RecommendationEngine.shared }
        
        // 注册学习路径管理
        register { LearningPathManager.shared }
        
        // 注册通知管理
        register { NotificationManager.shared }
        
        // 注册应用配置
        register { AppConfig.shared }
    }
    
    private func createDefaultService<T>(for type: T.Type) -> T {
        switch type {
        case is PersistenceController.Type:
            return PersistenceController.shared as! T
        case is SemanticSearchEngine.Type:
            return SemanticSearchEngine.shared as! T
        case is EnhancedSearchEngine.Type:
            return EnhancedSearchEngine.shared as! T
        case is SpacedRepetitionScheduler.Type:
            return SpacedRepetitionScheduler.shared as! T
        case is ReviewScheduler.Type:
            return ReviewScheduler.shared as! T
        case is ImprovedWindowManager.Type:
            return ImprovedWindowManager.shared as! T
        case is WindowManager.Type:
            return WindowManager.shared as! T
        case is RecommendationEngine.Type:
            return RecommendationEngine.shared as! T
        case is LearningPathManager.Type:
            return LearningPathManager.shared as! T
        case is NotificationManager.Type:
            return NotificationManager.shared as! T
        case is AppConfig.Type:
            return AppConfig.shared as! T
        default:
            fatalError("No default service available for type: \(type)")
        }
    }
    
    // MARK: - 服务重置（用于测试）
    
    func reset() {
        services.removeAll()
        factories.removeAll()
        setupDefaultServices()
    }
    
    // MARK: - 自定义服务注册（用于测试或扩展）
    
    func registerCustomService<T>(_ service: T) {
        register(service)
    }
    
    func registerCustomFactory<T>(_ factory: @escaping () -> T) {
        register(factory)
    }
}

// MARK: - 服务协议定义

protocol SearchService {
    func search(query: String, filters: SearchFilters, context: NSManagedObjectContext, limit: Int) -> [SearchResult]
    func getSearchSuggestions(query: String, context: NSManagedObjectContext, limit: Int) -> [SearchSuggestion]
    func findSimilarProblems(to problem: Problem, context: NSManagedObjectContext, limit: Int) -> [Problem]
}

protocol ReviewSchedulingService {
    func createInitialReviewPlan(for problem: Problem, context: NSManagedObjectContext) -> ReviewPlan?
    func completeReview(reviewPlan: ReviewPlan, score: Int, context: NSManagedObjectContext) -> ReviewPlan?
    func getTodayReviews(context: NSManagedObjectContext) -> [ReviewPlan]
    func getDueReviews(context: NSManagedObjectContext) -> [ReviewPlan]
}

protocol WindowManagerService {
    func showMainWindow()
    func showReviewWindow()
    func showAddProblemWindow()
    func showProblemDetail(_ problem: Problem)
    func closeAllWindows()
    func getActiveWindowCount() -> Int
}

protocol RecommendationService {
    func getSmartRecommendations() -> [RecommendationResult]
    func getAllProblems() -> [Problem]
    func analyzeWeaknessAreas() -> [WeaknessArea]
}

// MARK: - 扩展现有服务以符合协议

extension SemanticSearchEngine: SearchService {}
extension EnhancedSearchEngine: SearchService {}

extension SpacedRepetitionScheduler: ReviewSchedulingService {}
extension ReviewScheduler: ReviewSchedulingService {}

extension ImprovedWindowManager: WindowManagerService {}
extension WindowManager: WindowManagerService {}

extension RecommendationEngine: RecommendationService {}

// MARK: - 环境值注入

struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var serviceContainer: DependencyContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - 便捷的视图修饰器

extension View {
    func withServices<Content: View>(
        @ViewBuilder content: @escaping (DependencyContainer) -> Content
    ) -> some View {
        content(DependencyContainer.shared)
            .environment(\.serviceContainer, DependencyContainer.shared)
    }
}

// MARK: - 服务使用示例

struct ServiceUsageExample: View {
    @Environment(\.serviceContainer) private var container
    
    var body: some View {
        VStack {
            Text("服务依赖注入示例")
                .padding()
            
            Button("执行搜索") {
                performSearch()
            }
            
            Button("显示窗口") {
                showWindows()
            }
        }
    }
    
    private func performSearch() {
        let context = container.persistenceController.container.viewContext
        let searchService = container.semanticSearchEngine
        
        let results = searchService.search(
            query: "数组",
            filters: SearchFilters(),
            context: context,
            limit: 10
        )
        
        print("搜索结果: \(results.count) 个项目")
    }
    
    private func showWindows() {
        let windowService = container.improvedWindowManager
        windowService.showMainWindow()
        windowService.showReviewWindow()
    }
}

// MARK: - 测试支持

#if DEBUG
extension DependencyContainer {
    
    // 创建测试用的容器
    static func createTestContainer() -> DependencyContainer {
        let container = DependencyContainer()
        
        // 注册测试用的模拟服务
        container.registerCustomService(MockPersistenceController())
        container.registerCustomService(MockSearchEngine())
        container.registerCustomService(MockReviewScheduler())
        
        return container
    }
}

// MARK: - 模拟服务（用于测试）

class MockPersistenceController {
    static let test = PersistenceController(inMemory: true)
    let container: NSPersistentContainer
    
    init() {
        self.container = PersistenceController(inMemory: true).container
    }
}

class MockSearchEngine: SearchService {
    func search(query: String, filters: SearchFilters, context: NSManagedObjectContext, limit: Int) -> [SearchResult] {
        return []
    }
    
    func getSearchSuggestions(query: String, context: NSManagedObjectContext, limit: Int) -> [SearchSuggestion] {
        return []
    }
    
    func findSimilarProblems(to problem: Problem, context: NSManagedObjectContext, limit: Int) -> [Problem] {
        return []
    }
}

class MockReviewScheduler: ReviewSchedulingService {
    func createInitialReviewPlan(for problem: Problem, context: NSManagedObjectContext) -> ReviewPlan? {
        return nil
    }
    
    func completeReview(reviewPlan: ReviewPlan, score: Int, context: NSManagedObjectContext) -> ReviewPlan? {
        return nil
    }
    
    func getTodayReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        return []
    }
    
    func getDueReviews(context: NSManagedObjectContext) -> [ReviewPlan] {
        return []
    }
}

#endif