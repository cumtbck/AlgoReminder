import Foundation
import SwiftUI
import WebKit

// 未来可引入 Swift Package: https://github.com/gonzalezreal/MarkdownUI 或 Down (GitHub flavored).
// 先提供一个统一适配层，便于后续切换第三方库。

final class UnifiedMarkdownRenderer {
    static let shared = UnifiedMarkdownRenderer()
    private init() {}

    enum Engine {
        case builtIn   // 当前自研 MarkdownRenderer
        // case markdownUI  // 引入 MarkdownUI 后启用
        // case down        // 引入 Down 库后启用
    }

    var engine: Engine = .builtIn

    func render(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
        switch engine {
        case .builtIn:
            return MarkdownRenderer.shared.renderMarkdown(markdown, context: context)
        }
    }
}