import Cocoa
import SwiftUI

// MARK: - 改进的窗口管理器
// 说明：原实现使用自建串行队列 windowQueue 在后台线程读写 @Published activeWindows 与字典，
// 然后再回到主线程发送 objectWillChange。SwiftUI/Combine 期望所有 UI 相关可观察状态
// 在主线程修改，否则会出现主线程阻塞（Beachball）或偶发崩溃（EXC_BAD_ACCESS / data race）。
// 菜单栏回调本身运行在主线程，当快速多次点击菜单项时，原逻辑的跨线程往返 + 冷却递归调度
// 会造成大量异步嵌套，放大竞争窗口。这里将管理器改为 @MainActor，彻底保证：
// 1. 所有窗口创建/注册/销毁/查询在主线程执行；
// 2. 移除多余的串行队列与同步调用 windowQueue.sync，避免潜在死锁与卡顿；
// 3. 直接依赖 @Published 自动触发刷新，无需手动 objectWillChange.send();
// 4. 冷却逻辑保持，但用主线程调度更简洁安全。
// 这样可解决从菜单栏交互快速打开窗口导致的“光标转圈随后闪退”问题。
@MainActor
class ImprovedWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = ImprovedWindowManager()
    
    // MARK: - 窗口类型枚举
    enum WindowType: String, CaseIterable {
        case main = "main"
        case review = "review"
        case addProblem = "addProblem"
        case addNote = "addNote"
        case problemDetail = "problemDetail"
        case noteViewer = "noteViewer"
        case knowledgeGraph = "knowledgeGraph"
        case learningPaths = "learningPaths"
        case recommendations = "recommendations"
        
        var defaultSize: NSSize {
            switch self {
            case .main: return NSSize(width: 900, height: 600)
            case .review: return NSSize(width: 800, height: 600)
            case .addProblem: return NSSize(width: 600, height: 500)
            case .addNote: return NSSize(width: 700, height: 600)
            case .problemDetail: return NSSize(width: 700, height: 600)
            case .noteViewer: return NSSize(width: 900, height: 700)
            case .knowledgeGraph: return NSSize(width: 1000, height: 700)
            case .learningPaths: return NSSize(width: 800, height: 600)
            case .recommendations: return NSSize(width: 800, height: 600)
            }
        }
        
        var title: String {
            switch self {
            case .main: return "素晴らしき日々～不連続存在～"
            case .review: return "今日复习"
            case .addProblem: return "添加题目"
            case .addNote: return "添加笔记"
            case .problemDetail: return "题目详情"
            case .noteViewer: return "笔记查看器"
            case .knowledgeGraph: return "知识图谱"
            case .learningPaths: return "学习路径"
            case .recommendations: return "智能推荐"
            }
        }
        
        var styleMask: NSWindow.StyleMask {
            switch self {
            case .addProblem, .addNote:
                return [.titled, .closable, .miniaturizable]
            default:
                return [.titled, .closable, .miniaturizable, .resizable]
            }
        }
    }
    
    // MARK: - 窗口信息结构
    struct WindowInfo {
        let type: WindowType
        let window: NSWindow
        let identifier: String
        weak var data: AnyObject?
        
        init(type: WindowType, window: NSWindow, identifier: String, data: AnyObject? = nil) {
            self.type = type
            self.window = window
            self.identifier = identifier
            self.data = data
        }
    }
    
    // MARK: - 状态管理
    @Published private(set) var activeWindows: [WindowInfo] = []
    private var windowRegistry: [String: WindowInfo] = [:]
    
    // 性能优化：窗口创建限制和冷却时间
    private var lastWindowCreationTime: [WindowType: Date] = [:]
    private let windowCreationCooldown: TimeInterval = 0.1
    
    // 内存管理：定期清理无效窗口引用
    private var cleanupTimer: Timer?
    
    private override init() {
        super.init()
        setupWindowNotifications()
        startCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 窗口创建方法
    
    func showMainWindow() {
        createOrShowWindow(type: .main, identifier: "main_window") {
            ContentView()
        }
    }
    
    func showReviewWindow() {
        createOrShowWindow(type: .review, identifier: "review_window") {
            ReviewDashboardView()
        }
    }
    
    func showAddProblemWindow() {
        createOrShowWindow(type: .addProblem, identifier: "add_problem_window") {
            AddProblemView()
        }
    }
    
    func showAddNoteWindow() {
        createOrShowWindow(type: .addNote, identifier: "add_note_window") {
            AddNoteView()
        }
    }
    
    func showProblemDetail(_ problem: Problem) {
        guard let pid = problem.id else {
            NSLog("[ImprovedWindowManager] problemDetail: problem.id 为 nil，放弃打开窗口")
            return
        }
        let identifier = "problem_detail_\(pid.uuidString)"
        createOrShowWindow(type: .problemDetail, identifier: identifier, data: problem as AnyObject) {
            ProblemDetailView(problem: problem)
        }
    }
    
    func showNoteViewer(for problem: Problem) {
        guard let pid = problem.id else {
            NSLog("[ImprovedWindowManager] noteViewer: problem.id 为 nil，放弃打开窗口")
            return
        }
        let identifier = "note_viewer_\(pid.uuidString)"
        
        // 检查是否已有窗口
        if let existingWindowInfo = windowRegistry[identifier] {
            existingWindowInfo.window.makeKeyAndOrderFront(nil)
            existingWindowInfo.window.center()
            return
        }
        
        // 冷却时间检查
        if let lastCreation = lastWindowCreationTime[.noteViewer] {
            let timeSinceCreation = Date().timeIntervalSince(lastCreation)
            if timeSinceCreation < windowCreationCooldown {
                let delay = windowCreationCooldown - timeSinceCreation
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.showNoteViewer(for: problem)
                }
                return
            }
        }
        
        lastWindowCreationTime[.noteViewer] = Date()
        
        // 创建新的独立窗口视图
        let contentView = NoteViewerView(problem: problem, isStandaloneWindow: true)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environment(\.appConfig, DependencyContainer.shared.appConfig)
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口标题
        window.title = problem.title ?? "笔记查看器"
        
        // 设置窗口内容
        window.contentView = NSHostingView(rootView: contentView)
        
        // 设置窗口属性
        window.setFrameAutosaveName("NoteViewerWindow")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 700, height: 500)
        window.delegate = self
        
        // 确保标准按钮可见
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        
        // 注册窗口
        let windowInfo = WindowInfo(type: .noteViewer, window: window, identifier: identifier, data: problem as AnyObject)
        windowRegistry[identifier] = windowInfo
        activeWindows.append(windowInfo)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        window.center()
        NSLog("[ImprovedWindowManager] 成功创建笔记查看器独立窗口: %@", identifier)
    }
    
    func showKnowledgeGraph(context: NSManagedObjectContext) {
        createOrShowWindow(type: .knowledgeGraph, identifier: "knowledge_graph_window") {
            KnowledgeGraphView(context: context)
        }
    }
    
    func showLearningPaths() {
        createOrShowWindow(type: .learningPaths, identifier: "learning_paths_window") {
            LearningPathManagementView()
        }
    }
    
    func showRecommendations() {
        createOrShowWindow(type: .recommendations, identifier: "recommendations_window") {
            RecommendationDashboardView()
        }
    }
    
    // MARK: - 核心窗口管理逻辑
    
    private func createOrShowWindow<Content: View>(
        type: WindowType,
        identifier: String,
        data: AnyObject? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        // 冷却时间检查
        if let lastCreation = lastWindowCreationTime[type] {
            let timeSinceCreation = Date().timeIntervalSince(lastCreation)
            if timeSinceCreation < windowCreationCooldown {
                let delay = windowCreationCooldown - timeSinceCreation
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.createOrShowWindow(type: type, identifier: identifier, data: data, content: content)
                }
                return
            }
        }
        
        // 已存在则前置
        if let existingWindowInfo = windowRegistry[identifier] {
            existingWindowInfo.window.makeKeyAndOrderFront(nil)
            existingWindowInfo.window.center()
            return
        }
        
        lastWindowCreationTime[type] = Date()
        
        // 创建新窗口
        let window = createWindow(type: type, content: content)
        let windowInfo = WindowInfo(type: type, window: window, identifier: identifier, data: data)
        windowRegistry[identifier] = windowInfo
        activeWindows.append(windowInfo)
        window.makeKeyAndOrderFront(nil)
        window.center()
        NSLog("[ImprovedWindowManager] 成功创建窗口: %@", identifier)
    }
    
    private func createWindow<Content: View>(type: WindowType, @ViewBuilder content: @escaping () -> Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: type.defaultSize.width, height: type.defaultSize.height),
            styleMask: type.styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = type.title
        window.delegate = self
        
        // 安全地创建 rootView 和 NSHostingView
        let container = PersistenceController.shared
        let rootView = content()
            .environment(\.managedObjectContext, container.container.viewContext)
            .environment(\.appConfig, DependencyContainer.shared.appConfig)
        
        // 确保在主线程上创建 NSHostingView
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
        
        // 设置窗口属性
        window.minSize = NSSize(width: type.defaultSize.width * 0.7, height: type.defaultSize.height * 0.7)
        window.animationBehavior = .documentWindow
        
        return window
    }
    
    private func registerWindow(_ windowInfo: WindowInfo) {
        guard windowRegistry[windowInfo.identifier] == nil else { return }
        windowRegistry[windowInfo.identifier] = windowInfo
        activeWindows.append(windowInfo)
        NSLog("[ImprovedWindowManager] 注册窗口: %@; 当前数量=%d", windowInfo.identifier, activeWindows.count)
    }
    
    private func unregisterWindow(_ identifier: String) {
        guard windowRegistry[identifier] != nil else { return }
        windowRegistry.removeValue(forKey: identifier)
        activeWindows.removeAll { $0.identifier == identifier }
        NSLog("[ImprovedWindowManager] 注销窗口: %@; 剩余数量=%d", identifier, activeWindows.count)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // 找到对应的窗口信息并注销
        if let identifier = activeWindows.first(where: { $0.window == window })?.identifier {
            unregisterWindow(identifier)
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // 更新窗口顺序（将激活的窗口移到前面）
        if let index = activeWindows.firstIndex(where: { $0.window == window }) {
            let windowInfo = activeWindows.remove(at: index)
            activeWindows.insert(windowInfo, at: 0)
        }
    }
    
    // MARK: - 窗口查找和操作
    
    func findWindow<T>(ofType type: WindowType) -> T? {
        return activeWindows.first { $0.type == type }?.data as? T
    }
    
    func findWindow(withIdentifier identifier: String) -> NSWindow? {
        return windowRegistry[identifier]?.window
    }
    
    func bringWindowToFront(_ identifier: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let windowInfo = self.windowRegistry[identifier] else { return }
            windowInfo.window.makeKeyAndOrderFront(nil)
        }
    }
    
    // MARK: - 批量窗口操作
    
    func closeAllWindows(ofType type: WindowType) {
    let windowsToClose = activeWindows.filter { $0.type == type }
    for windowInfo in windowsToClose { windowInfo.window.close() }
    }
    
    func closeAllWindows() {
    let windows = activeWindows
    for windowInfo in windows { windowInfo.window.close() }
    }
    
    func minimizeAllWindows() {
    for windowInfo in activeWindows { windowInfo.window.miniaturize(nil) }
    }
    
    // MARK: - 窗口状态查询
    
    func isWindowOpen(_ type: WindowType) -> Bool {
        return activeWindows.contains { $0.type == type }
    }
    
    func isWindowOpen(withIdentifier identifier: String) -> Bool {
        return windowRegistry[identifier] != nil
    }
    
    func getActiveWindowCount() -> Int {
        return activeWindows.count
    }
    
    func getWindowInfo(for type: WindowType) -> [WindowInfo] {
        return activeWindows.filter { $0.type == type }
    }
    
    // MARK: - 窗口布局管理
    
    func tileWindows() {
    let visibleWindows = activeWindows.filter { !$0.window.isMiniaturized && $0.window.isVisible }
    guard !visibleWindows.isEmpty else { return }
    arrangeWindowsInGrid(visibleWindows.map { $0.window })
    }
    
    private func arrangeWindowsInGrid(_ windows: [NSWindow]) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let windowCount = windows.count
        
        // 计算网格布局
        let cols = Int(ceil(sqrt(Double(windowCount))))
        let rows = Int(ceil(Double(windowCount) / Double(cols)))
        
        let windowWidth = screenFrame.width / CGFloat(cols)
        let windowHeight = screenFrame.height / CGFloat(rows)
        
        for (index, window) in windows.enumerated() {
            let row = index / cols
            let col = index % cols
            
            let x = screenFrame.minX + CGFloat(col) * windowWidth
            let y = screenFrame.maxY - CGFloat(row + 1) * windowHeight
            
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
    }
    
    // MARK: - 清理和维护
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performWindowCleanup()
        }
    }
    
    private func performWindowCleanup() {
        // 清理无效窗口引用
        let invalidIdentifiers = windowRegistry.filter { _, info in
            let window = info.window
            return window.windowController == nil || !window.isVisible
        }.keys
        for identifier in invalidIdentifiers {
            windowRegistry.removeValue(forKey: identifier)
            activeWindows.removeAll { $0.identifier == identifier }
        }
        let now = Date()
        lastWindowCreationTime = lastWindowCreationTime.filter { _, time in
            now.timeIntervalSince(time) < 60.0
        }
        if !invalidIdentifiers.isEmpty {
            NSLog("[ImprovedWindowManager] 清理了 %d 个无效窗口引用", invalidIdentifiers.count)
        }
    }
    
    // MARK: - 设置通知监听
    
    private func setupWindowNotifications() {
        // 依赖 NSWindowDelegate 回调即可，移除重复 Notification 监听以避免重复调用注销逻辑
    }
}

// MARK: - 向后兼容的扩展
extension ImprovedWindowManager {
    
    // 提供向后兼容的接口
    func showMainWindowCompat() {
        showMainWindow()
    }
    
    func showReviewWindowCompat() {
        showReviewWindow()
    }
    
    func showAddProblemWindowCompat() {
        showAddProblemWindow()
    }
    
    func showAddNoteWindowCompat() {
        showAddNoteWindow()
    }
    
    func showProblemDetailCompat(_ problem: Problem) {
        showProblemDetail(problem)
    }
    
    func showNoteViewerCompat(for problem: Problem) {
        showNoteViewer(for: problem)
    }
    
    func closeAllWindowsCompat() {
        closeAllWindows()
    }
}
