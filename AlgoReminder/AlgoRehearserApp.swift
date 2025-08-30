import SwiftUI
import CoreData
import UserNotifications

@main
@MainActor
struct AlgoRehearserApp: App {
    // 使用依赖注入容器
    private let container = DependencyContainer.shared
    
    // 从容器中获取服务
    private var persistenceController: PersistenceController { container.persistenceController }
    private var notificationManager: NotificationManager { container.notificationManager }
    private var appConfig: AppConfig { container.appConfig }
    
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.appConfig, appConfig)
                .environmentObject(settings)
                .accentColor(settings.accentColor)
                .preferredColorScheme(colorScheme(for: settings.themeMode))
                .onAppear {
                    setupMenuBar()
                    requestNotificationPermissions()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    private func setupMenuBar() {
        MenuBarController.shared.setup()
    }
    
    private func requestNotificationPermissions() {
        notificationManager.requestAuthorization()
        notificationManager.setupNotificationCategories()
    }
}

private func colorScheme(for mode: AppSettings.ThemeMode) -> ColorScheme? {
    switch mode {
    case .light: return .light
    case .dark: return .dark
    case .system: return nil
    }
}

@MainActor
class MenuBarController: NSObject, ObservableObject {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var windowManager = WindowManager.shared
    // 增加任务数缓存，避免频繁获取
    private var cachedReviewCount: Int = 0
    // 避免多次更新UI
    private var isUpdatingIcon = false
    
    // 设置观察者
    private var settingsObserver: NSObjectProtocol?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateMenuBarIconAppearance()
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 监听设置变化
        setupSettingsObservers()
        
        // 初始更新一次图标
        updateMenuBarIcon()
        
        // 添加复习计划变更通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReviewPlanChange),
            name: .reviewCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReviewPlanChange),
            name: .reviewSkipped,
            object: nil
        )
        
        // Update icon every minute，降低频率减轻系统负担
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateMenuBarIcon()
        }
        
        let menu = NSMenu()
        // 关闭自动根据 responder chain 启用/禁用，否则找不到 target 时会呈灰色
        menu.autoenablesItems = false
        // 逐项创建并指定 target，防止因为未进入 responder chain 而灰掉
        func makeItem(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            item.isEnabled = true
            return item
        }
        let quitItem = makeItem("退出", #selector(quitApp), key: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                showPopover()
            }
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem?.button else { return }
        
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
        popover?.behavior = .transient
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - 设置观察器
    private func setupSettingsObservers() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarIconAppearance()
        }
    }
    
    // 更新菜单栏图标外观
    private func updateMenuBarIconAppearance() {
        guard let button = statusItem?.button else { return }
        
        let settings = AppSettings.shared
        let iconName = settings.menuBarIconName
        
        // 创建基础图标
        guard var icon = NSImage(systemSymbolName: iconName, accessibilityDescription: "AlgoRehearser") else {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AlgoRehearser")
            return
        }
        
        // 应用颜色
        if settings.menuBarIconColor != Color.primary {
            icon = icon.tinting(with: NSColor(settings.menuBarIconColor))
        }
        
        button.image = icon
    }
    
    // 响应复习计划变更
    @objc func handleReviewPlanChange(_ notification: Notification) {
        // 添加微小延迟确保数据库更新完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateMenuBarIcon()
        }
    }
    
    // 更新为异步执行获取今日复习
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        
        // 防止重复更新
        if isUpdatingIcon {
            return
        }
        
        isUpdatingIcon = true
        
        // 在后台队列中获取复习数据，避免主线程卡顿
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let persistence = PersistenceController.shared
            let bgContext = persistence.container.newBackgroundContext()
            bgContext.perform {
                let todayReviews = ReviewScheduler.shared.getTodayReviews(context: bgContext)
                let count = todayReviews.count
                DispatchQueue.main.async {
                    self.cachedReviewCount = count
                    self.updateButtonImage(count: count, button: button)
                    self.isUpdatingIcon = false
                }
            }
        }
    }
    
    // 将UI更新部分拆分为单独方法
    private func updateButtonImage(count: Int, button: NSButton) {
        let settings = AppSettings.shared
        
        // Create icon with badge if there are reviews
        if count > 0 && settings.showMenuBarBadge {
            guard let icon = NSImage(systemSymbolName: settings.menuBarIconName, accessibilityDescription: "AlgoRehearser") else {
                button.image = NSImage(systemSymbolName: settings.menuBarIconName, accessibilityDescription: "AlgoRehearser")
                return
            }
            
            // Add badge text
            let badgeText = NSAttributedString(
                string: count > 9 ? "9+" : "\(count)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
            )
            
            // Create a new image with badge（扩大画布，避免徽章被裁剪）
            let imageSize = NSSize(width: 20, height: 20)
            let badgeImage = NSImage(size: imageSize)
            
            badgeImage.lockFocus()
            
            // Draw background circle (位置放在右上角且不越界)
            let badgeDiameter: CGFloat = 11
            let badgeRect = NSRect(x: imageSize.width - badgeDiameter - 1, y: imageSize.height - badgeDiameter - 1, width: badgeDiameter, height: badgeDiameter)
            NSColor(settings.badgeColor).setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
            
            // Draw badge text
            let textSize = badgeText.size()
            badgeText.draw(at: NSPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2))
            
            badgeImage.unlockFocus()
            
            // Combine images
            let finalImage = NSImage(size: imageSize)
            finalImage.lockFocus()
            // 将原图居中放置
            let iconRect = NSRect(x: (imageSize.width - 16)/2, y: (imageSize.height - 16)/2, width: 16, height: 16)
            icon.draw(in: iconRect)
            badgeImage.draw(in: NSRect(origin: .zero, size: imageSize))
            finalImage.unlockFocus()
            
            button.image = finalImage
            button.image?.isTemplate = false // 使用彩色徽章
        } else {
            let settings = AppSettings.shared
            button.image = NSImage(systemSymbolName: settings.menuBarIconName, accessibilityDescription: "AlgoRehearser")
        }
    }
}

// MARK: - NSImage 扩展
extension NSImage {
    func tinting(with color: NSColor) -> NSImage {
        let tintedImage = NSImage(size: size)
        
        tintedImage.lockFocus()
        
        // 绘制原始图像
        draw(in: NSRect(origin: .zero, size: size))
        
        // 应用颜色覆盖
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceIn)
        
        tintedImage.unlockFocus()
        
        return tintedImage
    }
}

struct MenuBarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingProblemDetail = false
    @State private var selectedProblem: Problem?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ReviewPlan.scheduledAt, ascending: true)],
        predicate: NSPredicate(format: "status == %@", "pending"),
        animation: .default)
    private var pendingReviews: FetchedResults<ReviewPlan>
    
    var todayReviews: [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return pendingReviews.filter { review in
            guard let scheduledAt = review.scheduledAt else { return false }
            return scheduledAt >= today && scheduledAt < tomorrow
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("素晴らしき日々～不連続存在～")
                .font(.headline)
                .padding(.top, 8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("今日复习")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(todayReviews.count) 个任务")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if todayReviews.isEmpty {
                    Text("今日无复习任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(todayReviews.prefix(3), id: \.id) { review in
                            Button(action: {
                                selectedProblem = review.problem
                                showingProblemDetail = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(review.problem?.title ?? "未知题目")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        HStack {
                                            Text(review.problem?.source ?? "")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            
                                            Text("第\(Int(review.intervalLevel) + 1)次")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("点击查看题目详情")
                        }
                        
                        if todayReviews.count > 3 {
                            Text("还有 \(todayReviews.count - 3) 个任务...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
            
            Divider()
            
            Text("请在主界面中管理应用")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: 280)
        .sheet(isPresented: $showingProblemDetail) {
            if let problem = selectedProblem {
                ProblemDetailView(problem: problem)
            }
        }
    }
}

// MARK: - 重构后的窗口管理器（向后兼容）
@MainActor
class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    
    // 使用新的改进窗口管理器
    private let improvedWindowManager = ImprovedWindowManager.shared
    
    private override init() {
        super.init()
    }
    
    // MARK: - 向后兼容的公共接口
    
    func showMainWindow() {
        improvedWindowManager.showMainWindow()
    }
    
    func showReviewWindow() {
        improvedWindowManager.showReviewWindow()
    }
    
    func showAddProblemWindow() {
        improvedWindowManager.showAddProblemWindow()
    }
    
    func showAddNoteWindow() {
        improvedWindowManager.showAddNoteWindow()
    }
    
    func showProblemDetail(_ problem: Problem) {
        improvedWindowManager.showProblemDetail(problem)
    }
    
    func showNoteViewer(_ problem: Problem) {
        improvedWindowManager.showNoteViewer(for: problem)
    }
    
    func closeAllWindows() {
        improvedWindowManager.closeAllWindows()
    }
    
    // MARK: - 新增的高级功能
    
    func showKnowledgeGraph(context: NSManagedObjectContext) {
        improvedWindowManager.showKnowledgeGraph(context: context)
    }
    
    func showLearningPaths() {
        improvedWindowManager.showLearningPaths()
    }
    
    func showRecommendations() {
        improvedWindowManager.showRecommendations()
    }
    
    func tileWindows() {
        improvedWindowManager.tileWindows()
    }
    
    func isWindowOpen(ofType type: ImprovedWindowManager.WindowType) -> Bool {
        return improvedWindowManager.isWindowOpen(type)
    }
    
    func getActiveWindowCount() -> Int {
        return improvedWindowManager.getActiveWindowCount()
    }
}
