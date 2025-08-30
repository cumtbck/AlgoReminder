import SwiftUI
import WebKit
import CoreData
import AppKit

extension NoteViewerView {
    func renderMarkdownContent(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
        UnifiedMarkdownRenderer.shared.render(markdown, context: context)
    }
    
    // 创建一个独立窗口的方法
    func openInStandaloneWindow(with problem: Problem) -> NSWindow {
        // 创建标准窗口，添加红黄绿按钮（标准macOS窗口控制）
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口标题
        window.title = problem.title ?? "笔记查看器"
        
        // 设置窗口内容
        let contentView = NoteViewerView(problem: problem)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        window.contentView = NSHostingView(rootView: contentView)
        
        // 设置窗口属性
        window.setFrameAutosaveName("NoteViewerWindow")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 700, height: 500)
        
        // 启用红黄绿按钮
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        
        return window
    }
}

extension NoteContentDisplay {
    func renderMarkdownContent(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
        UnifiedMarkdownRenderer.shared.render(markdown, context: context)
    }
}

// 自定义窗口控制器视图
struct MacWindowControlButtons: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 确保父视图存在
        guard let window = nsView.window else { return }
        
        // 设置窗口属性
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        
        // 确保标准按钮可见
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
}
