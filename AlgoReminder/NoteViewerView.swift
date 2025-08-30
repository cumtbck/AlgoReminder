import SwiftUI
import WebKit
import CoreData

struct NoteViewerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var problem: Problem
    @State private var selectedNote: Note?
    @State private var showSidebar: Bool = true
    @State private var sidebarWidth: CGFloat = 300
    @State private var isStandaloneWindow: Bool
    
    private var notes: [Note] {
        guard let notesSet = problem.notes else { return [] }
        // 按更新时间排序，最新在前
        return (Array(notesSet) as? [Note] ?? []).sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }
    
    init(problem: Problem, isStandaloneWindow: Bool = false) {
        self.problem = problem
        self._isStandaloneWindow = State(initialValue: isStandaloneWindow)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                if showSidebar {
                    noteListPane
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    resizer
                }
                contentPane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    // 允许随窗口调整，仅设置最小尺寸
    .frame(minWidth: 720, minHeight: 520)
        .onAppear { 
            if selectedNote == nil { selectedNote = notes.first } 
            
            // 如果是独立窗口，设置标题栏样式
            if isStandaloneWindow {
                setupTitleBarForStandaloneWindow()
            }
        }
    }
    
    // 设置独立窗口的标题栏样式
    private func setupTitleBarForStandaloneWindow() {
        DispatchQueue.main.async {
            if let hostingView = NSApplication.shared.windows.first(where: { $0.title == problem.title ?? "笔记查看器" })?.contentView,
               let window = hostingView.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .visible
                window.standardWindowButton(.closeButton)?.isHidden = false
                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                window.standardWindowButton(.zoomButton)?.isHidden = false
            }
        }
    }
    
    // MARK: Header
    private var header: some View {
        HStack(alignment: .center) {
            if !isStandaloneWindow {
                // 只在非独立窗口模式下显示这个占位符
                MacWindowControlButtons()
                    .frame(width: 70, height: 20)
            } else {
                // 在独立窗口模式下添加空间，为系统按钮腾出位置
                Spacer().frame(width: 70)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(problem.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                Text("笔记查看器")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                // 侧栏显示切换
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() } }) {
                    Image(systemName: showSidebar ? "sidebar.leading" : "sidebar.left")
                        .help(showSidebar ? "隐藏笔记列表" : "显示笔记列表")
                }.buttonStyle(.plain)

                // 在非独立窗口模式下显示关闭按钮
                if !isStandaloneWindow {
                    Button("关闭") { dismiss() }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: Left Pane (Note List)
    private var noteListPane: some View {
        VStack(spacing: 0) {
            // 列表标题栏
            HStack {
                Text("笔记 (\(notes.count))").font(.subheadline.bold())
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            if notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary)
                    Text("暂无笔记").font(.footnote).foregroundColor(.secondary)
                    Text("请导入 Markdown 文件").font(.caption2).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { 
                    LazyVStack(spacing: 6) {
                        ForEach(notes, id: \..id) { note in
                            noteRow(note)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // 拖动调节条
    private var resizer: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 4)
            .overlay(Rectangle().fill(Color.secondary.opacity(0.05)))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let newWidth = sidebarWidth + value.translation.width
                    sidebarWidth = min(max(newWidth, 200), 500)
                })
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .padding(.vertical, 0)
            .background(Color.primary.opacity(0.02))
    }
    
    @ViewBuilder private func noteRow(_ note: Note) -> some View {
        let isSelected = selectedNote?.id == note.id
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(note.title ?? "Untitled")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
            }
            HStack(spacing: 4) {
                Text(relativeDate(note.updatedAt)).font(.caption2).foregroundColor(.secondary)
                if let imported = note.importedFromURL { Text(URL(fileURLWithPath: imported).lastPathComponent).font(.caption2).foregroundColor(.secondary).lineLimit(1) }
            }
            if let md = note.rawMarkdown { Text(notePreview(md)).font(.caption2).foregroundColor(.secondary).lineLimit(2) }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selectedNote = note } }
        .contextMenu {
            Button("复制标题") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.title ?? "", forType: .string) }
            if let imported = note.importedFromURL { Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: imported)]) } }
        }
    }
    
    private func relativeDate(_ date: Date?) -> String { guard let d = date else { return "未知时间" }; let fmt = RelativeDateTimeFormatter(); fmt.unitsStyle = .abbreviated; return fmt.localizedString(for: d, relativeTo: Date()) }
    private func notePreview(_ md: String) -> String { let trimmed = md.trimmingCharacters(in: .whitespacesAndNewlines); if trimmed.count <= 100 { return trimmed } else { return String(trimmed.prefix(100)) + "…" } }
    
    // MARK: Right Pane (Content)
    private var contentPane: some View {
        Group {
            if let note = selectedNote ?? notes.first {
                NoteContentDisplay(note: note, hideTitle: !showSidebar)
                    .id(note.id) // 切换时滚动顶部
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 54))
                        .foregroundColor(.secondary)
                    Text("未选择笔记").font(.headline).foregroundColor(.secondary)
                    Text("在左侧选择一个笔记进行查看").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct NoteContentDisplay: View {
    @ObservedObject var note: Note
    @Environment(\.managedObjectContext) private var viewContext
    var hideTitle: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if !hideTitle {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.title ?? "Untitled Note").font(.title3.weight(.semibold))
                        HStack(spacing: 12) {
                            if let importedFrom = note.importedFromURL {
                                Label(URL(fileURLWithPath: importedFrom).lastPathComponent, systemImage: "tray.and.arrow.down")
                                    .labelStyle(.iconOnly)
                                    .help(URL(fileURLWithPath: importedFrom).lastPathComponent)
                            }
                            Text("更新于: \(formattedDate(note.updatedAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                Divider()
            }
            AdvancedMarkdownView(
                originalMarkdown: note.rawMarkdown ?? "",
                context: viewContext,
                onLink: { target, type in handleBidirectionalLinkClick(target: target, type: type) },
                onUpdateMarkdown: { updated in if note.rawMarkdown != updated { note.rawMarkdown = updated; try? viewContext.save() } }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func markdownToSimpleHTML(_ markdown: String) -> String { MarkdownRenderer.shared.renderMarkdown(markdown) }
    private func formattedDate(_ date: Date?) -> String { guard let d = date else { return "未知" }; let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: d) }
    
    private func handleBidirectionalLinkClick(target: String, type: String) {
        switch type {
        case "problem":
            // Find and show the problem
            if let problem = findProblemByTitle(target) {
                showProblemDetail(problem)
            }
        case "note":
            // Find and show the note
            if let note = findNoteByTitle(target) {
                showNoteDetail(note)
            }
        case "broken":
            // Offer to create the missing item
            showCreateItemAlert(target)
        default:
            break
        }
    }
    
    private func findProblemByTitle(_ title: String) -> Problem? {
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", title)
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
    }
    
    private func findNoteByTitle(_ title: String) -> Note? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", title)
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
    }
    
    private func showProblemDetail(_ problem: Problem) {
        // Create and show problem detail window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = problem.title ?? "题目详情"
        window.contentView = NSHostingView(rootView: ProblemDetailView(problem: problem))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    private func showNoteDetail(_ note: Note) {
        // 创建和显示笔记查看器独立窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = note.title ?? "笔记详情"
        
        let contentView = NoteViewerView(problem: note.problems?.anyObject() as? Problem ?? createDummyProblem(), isStandaloneWindow: true)
            .environment(\.managedObjectContext, viewContext)
        
        window.contentView = NSHostingView(rootView: contentView)
        
        // 设置窗口属性
        window.setFrameAutosaveName("NoteDetailWindow")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 700, height: 500)
        
        // 确保标准按钮可见
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    private func createDummyProblem() -> Problem {
        let problem = Problem(context: viewContext)
        problem.id = UUID()
        problem.title = "关联题目"
        problem.source = "Imported"
        problem.difficulty = "中等"
        return problem
    }
    
    private func showCreateItemAlert(_ target: String) {
        let alert = NSAlert()
        alert.messageText = "未找到\"\(target)\""
        alert.informativeText = "您想要创建一个新的题目还是笔记？"
        alert.addButton(withTitle: "创建题目")
        alert.addButton(withTitle: "创建笔记")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Create problem
            showCreateProblemWindow(target)
        case .alertSecondButtonReturn:
            // Create note
            showCreateNoteWindow(target)
        default:
            break
        }
    }
    
    private func showCreateProblemWindow(_ title: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "添加题目"
        window.contentView = NSHostingView(rootView: AddProblemView(preFilledTitle: title))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    private func showCreateNoteWindow(_ title: String) {
        // This would require creating a new note creation view
        // For now, just ignore
    }
}

struct WebView: NSViewRepresentable {
    let html: String
    let onLinkClick: ((String, String) -> Void)?
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        if onLinkClick != nil {
            configuration.userContentController.add(context.coordinator, name: "linkHandler")
        }
        let preferences = WKPreferences(); preferences.javaScriptEnabled = true; configuration.preferences = preferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        // 初次加载使用异步，确保布局已建立，避免进程过早终止
        DispatchQueue.main.async { [initialHTML = html] in
            context.coordinator.load(html: initialHTML)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.load(html: html)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkClick: onLinkClick)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let onLinkClick: ((String, String) -> Void)?
        weak var webView: WKWebView?
        private var lastHTMLHash: Int = 0
        private var isReloadingAfterCrash = false

        init(onLinkClick: ((String, String) -> Void)?) {
            self.onLinkClick = onLinkClick
        }

        func load(html: String) {
            guard let webView = webView else { return }
            let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeHTML: String = trimmed.isEmpty ? "<html><body><h3>笔记内容为空</h3></body></html>" : html
            let newHash = safeHTML.hashValue
            guard newHash != lastHTMLHash else { return } // 避免重复加载
            lastHTMLHash = newHash
            webView.loadHTMLString(safeHTML, baseURL: nil)
        }

        // MARK: WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView: 加载完成, 内容长度=")
            isReloadingAfterCrash = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView: 加载失败 -> \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView: 预加载失败 -> \(error.localizedDescription)")
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // 处理进程崩溃或被系统终止
            print("WebView: Web 内容进程被终止，尝试恢复加载")
            guard !isReloadingAfterCrash else { return }
            isReloadingAfterCrash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.load(html: webView.backForwardList.currentItem?.initialURL.absoluteString ?? "")
            }
        }

        // MARK: 外部链接处理
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url, ["http","https"].contains(url.scheme) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // MARK: JS 消息
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "linkHandler",
                  let body = message.body as? [String: String],
                  let target = body["target"],
                  let type = body["type"] else { return }
            onLinkClick?(target, type)
        }
    }
}

struct NoteWindowView: View {
    @ObservedObject var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var zoomLevel: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // 标题部分向右移，为系统按钮预留空间
                Spacer().frame(width: 70)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title ?? "Untitled Note")
                        .font(.headline)
                    
                    if let importedFrom = note.importedFromURL {
                        Text("导入自: \(URL(fileURLWithPath: importedFrom).lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 缩放控制
                HStack(spacing: 8) {
                    Button(action: {
                        zoomLevel = max(0.5, zoomLevel - 0.1)
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("\(Int(zoomLevel * 100))%")
                        .font(.caption)
                        .frame(width: 40)
                    
                    Button(action: {
                        zoomLevel = min(2.0, zoomLevel + 0.1)
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            AdvancedMarkdownView(
                originalMarkdown: note.rawMarkdown ?? "",
                context: viewContext,
                onLink: { target, type in print("Link tapped: \(target) type=\(type)") },
                onUpdateMarkdown: { updated in if note.rawMarkdown != updated { note.rawMarkdown = updated; try? viewContext.save() } }
            )
            .scaleEffect(zoomLevel)
            .animation(.easeInOut(duration: 0.15), value: zoomLevel)
        }
        .frame(width: 800, height: 600)
        .onAppear {
            // 在出现时配置窗口属性
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.title == note.title ?? "Untitled Note" }) {
                    // 确保系统按钮可见
                    window.standardWindowButton(.closeButton)?.isHidden = false
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                    window.standardWindowButton(.zoomButton)?.isHidden = false
                    window.titlebarAppearsTransparent = true
                }
            }
        }
    }
}

// 添加可缩放的WebView组件
struct ZoomableWebView: NSViewRepresentable {
    let html: String
    @Binding var zoomLevel: CGFloat
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
        nsView.setMagnification(zoomLevel, centeredAt: .zero)
    }
}

#Preview {
    NoteViewerView(problem: {
        let context = PersistenceController.preview.container.viewContext
        let problem = Problem(context: context)
        problem.id = UUID()
        problem.title = "示例题目"
        problem.source = "LeetCode"
        problem.difficulty = "中等"
        return problem
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
