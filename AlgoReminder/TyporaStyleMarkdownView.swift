import SwiftUI
import WebKit
import CoreData
import AppKit

struct TyporaStyleMarkdownView: View {
    let markdown: String
    let context: NSManagedObjectContext?
    var onLink: (String, String) -> Void
    var onUpdateMarkdown: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 预览内容区域
            WebViewRepresentable(
                html: EnhancedMarkdownRenderer.shared.renderTyporaStyleMarkdown(markdown, context: context),
                onLinkClick: onLink
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    struct WebViewRepresentable: NSViewRepresentable {
        let html: String
        let onLinkClick: (String, String) -> Void
        
        func makeNSView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let userContentController = WKUserContentController()
            userContentController.add(context.coordinator, name: "linkHandler")
            configuration.userContentController = userContentController
            
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            
            // 初次加载 HTML
            DispatchQueue.main.async { self.loadHTML(webView, html: html, coordinator: context.coordinator) }
            
            return webView
        }
        
        func updateNSView(_ nsView: WKWebView, context: Context) {
            // 仅在内容变化时重新加载，避免频繁销毁 Web 内容进程
            loadHTML(nsView, html: html, coordinator: context.coordinator)
        }
        
        private func loadHTML(_ webView: WKWebView, html: String, coordinator: Coordinator) {
            let safeHTML = html.isEmpty ? getEmptyHTML() : html
            let newHash = safeHTML.hashValue
            if newHash == coordinator.lastHTMLHash {
                return // 无变化
            }
            coordinator.lastHTMLHash = newHash
            coordinator.pendingWorkItem?.cancel()
            let work = DispatchWorkItem { [weak webView] in
                guard let wv = webView else { return }
                print("[TyporaStyleMarkdownView] Loading HTML (hash=\(newHash)) length=\(safeHTML.count)")
                wv.loadHTMLString(safeHTML, baseURL: nil)
            }
            coordinator.pendingWorkItem = work
            // 防抖：延迟极短以合并连续状态更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
        
        private func getEmptyHTML() -> String {
            return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 40px;
                    background-color: #f8f9fa;
                    color: #333;
                }
                .empty-container {
                    text-align: center;
                    padding: 60px 20px;
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                .empty-icon {
                    font-size: 48px;
                    color: #dee2e6;
                    margin-bottom: 16px;
                }
                .empty-title {
                    font-size: 18px;
                    font-weight: 600;
                    color: #495057;
                    margin-bottom: 8px;
                }
                .empty-subtitle {
                    font-size: 14px;
                    color: #6c757d;
                }
            </style>
        </head>
        <body>
            <div class="empty-container">
                <div class="empty-icon">📝</div>
                <div class="empty-title">笔记内容为空</div>
                <div class="empty-subtitle">此笔记暂无内容</div>
            </div>
        </body>
        </html>
        """
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(onLinkClick: onLinkClick)
        }
        
        class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
            let onLinkClick: (String, String) -> Void
            var currentHTML: String = ""
            var lastHTMLHash: Int = 0
            var pendingWorkItem: DispatchWorkItem?
            
            init(onLinkClick: @escaping (String, String) -> Void) {
                self.onLinkClick = onLinkClick
            }
            
            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                guard message.name == "linkHandler",
                      let body = message.body as? [String: String],
                      let target = body["target"],
                      let type = body["type"] else {
                    return
                }
                onLinkClick(target, type)
            }
            
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                print("[TyporaStyleMarkdownView] WebView load finished")
            }
            
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                print("[TyporaStyleMarkdownView] WebView failed: \(error.localizedDescription)")
            }
            
            func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                if navigationAction.navigationType == .linkActivated,
                   let url = navigationAction.request.url,
                   ["http", "https"].contains(url.scheme) {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.allow)
            }
        }
    }
    
    // MARK: - 增强的Markdown渲染器
    class EnhancedMarkdownRenderer: ObservableObject {
        static let shared = EnhancedMarkdownRenderer()
        
        private init() {}
        
        func renderTyporaStyleMarkdown(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
            print("Rendering markdown, length: \(markdown.count)")
            let processedMarkdown = preprocessMarkdown(markdown, context: context)
            let html = convertMarkdownToHTML(processedMarkdown)
            let wrappedHTML = wrapInHTML(html)
            // 检查正文是否为空（去掉标签后） -> 回退基础渲染避免空白
            let textOnly = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if textOnly.isEmpty {
                print("[TyporaStyleMarkdownView] Empty HTML after conversion, fallback to basic renderer")
                return MarkdownRenderer.shared.renderMarkdown(markdown, context: context)
            }
            print("Generated HTML, length: \(wrappedHTML.count) preview: \(wrappedHTML.prefix(120))...")
            return wrappedHTML
        }
        
        private func preprocessMarkdown(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
            var processed = markdown
            
            // 处理双向链接
            processed = processBidirectionalLinks(processed, context: context)
            
            // 处理任务列表
            processed = processTaskLists(processed)
            
            // 处理表格
            processed = processTables(processed)
            
            // 处理脚注
            processed = processFootnotes(processed)
            
            // 处理数学公式
            processed = processMathExpressions(processed)
            
            return processed
        }
        
        private func convertMarkdownToHTML(_ markdown: String) -> String {
            var html = escapeHTML(markdown)
            
            // 代码块（优先处理）
            html = processCodeBlocks(html)
            
            // 标题
            html = processHeaders(html)
            
            // 强调文本
            html = processEmphasis(html)
            
            // 行内代码
            html = processInlineCode(html)
            
            // 链接和图片
            html = processLinks(html)
            html = processImages(html)
            
            // 引用
            html = processBlockquotes(html)
            
            // 列表
            html = processUnorderedLists(html)
            html = processOrderedList(html)
            
            // 水平线
            html = processHorizontalRules(html)
            
            // 段落
            html = processParagraphs(html)
            
            return html
        }
        
        private func processCodeBlocks(_ html: String) -> String {
            let pattern = "```([a-zA-Z0-9+*-]*)\\n([\\s\\S]*?)```"
            let regex = try! NSRegularExpression(pattern: pattern, options: [])
            
            return regex.stringByReplacingMatches(
                in: html,
                options: [],
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<pre><code class=\"language-$1\">$2</code></pre>"
            )
        }
        
        private func processHeaders(_ html: String) -> String {
            var processed = html
            
            // 处理 Setext 风格的标题
            processed = processed.replacingOccurrences(
                of: "^(.+)\n=+$",
                with: "<h1>$1</h1>",
                options: .regularExpression
            )
            processed = processed.replacingOccurrences(
                of: "^(.+)\n-+$",
                with: "<h2>$1</h2>",
                options: .regularExpression
            )
            
            // 处理 ATX 风格的标题
            for i in 1...6 {
                // 使用 (?m) 多行模式使 ^ 匹配每行开头
                let pattern = "(?m)^#{\(i)}\\s+(.+)$"
                processed = processed.replacingOccurrences(of: pattern, with: "<h\(i)>$1</h\(i)>", options: .regularExpression)
            }
            
            return processed
        }
        
        private func processEmphasis(_ html: String) -> String {
            var processed = html
            
            // 粗体
            processed = processed.replacingOccurrences(
                of: "\\*\\*(.+?)\\*\\*",
                with: "<strong>$1</strong>",
                options: .regularExpression
            )
            processed = processed.replacingOccurrences(
                of: "__(.+?)__",
                with: "<strong>$1</strong>",
                options: .regularExpression
            )
            
            // 斜体
            processed = processed.replacingOccurrences(
                of: "\\*(.+?)\\*",
                with: "<em>$1</em>",
                options: .regularExpression
            )
            processed = processed.replacingOccurrences(
                of: "_(.+?)_",
                with: "<em>$1</em>",
                options: .regularExpression
            )
            
            // 删除线
            processed = processed.replacingOccurrences(
                of: "~~(.+?)~~",
                with: "<del>$1</del>",
                options: .regularExpression
            )
            
            return processed
        }
        
        private func processInlineCode(_ html: String) -> String {
            return html.replacingOccurrences(
                of: "`([^`]+?)`",
                with: "<code>$1</code>",
                options: .regularExpression
            )
        }
        
        private func processLinks(_ html: String) -> String {
            return html.replacingOccurrences(
                of: "\\[([^\\]]+?)\\]\\(([^)]+?)\\)",
                with: "<a href=\"$2\" target=\"_blank\">$1</a>",
                options: .regularExpression
            )
        }
        
        private func processImages(_ html: String) -> String {
            return html.replacingOccurrences(
                of: "!\\[([^\\]]+?)\\]\\(([^)]+?)\\)",
                with: "<img src=\"$2\" alt=\"$1\" style=\"max-width: 100%; height: auto; border-radius: 4px; margin: 8px 0;\">",
                options: .regularExpression
            )
        }
        
        private func processBlockquotes(_ html: String) -> String {
            let pattern = "^> (.+)$"
            let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            var processed = html
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: processed) {
                    let line = String(processed[range])
                    let content = String(line.dropFirst(2))
                    let replacement = "<blockquote>\(content)</blockquote>"
                    processed.replaceSubrange(range, with: replacement)
                }
            }
            
            return processed
        }
        
        private func processUnorderedLists(_ html: String) -> String {
            return processLists(html, pattern: "^[-*+] (.+)$", listType: "ul")
        }
        
        private func processOrderedList(_ html: String) -> String {
            return processLists(html, pattern: "^\\d+\\. (.+)$", listType: "ol")
        }
        
        private func processLists(_ html: String, pattern: String, listType: String) -> String {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            
            guard !matches.isEmpty else { return html }
            
            var processed = html
            var listItems: [(NSRange, String)] = []
            
            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let content = String(html[contentRange])
                    listItems.append((match.range, content))
                }
            }
            
            // 分组连续的列表项
            var lists: [[(NSRange, String)]] = []
            var currentList: [(NSRange, String)] = []
            
            for i in 0..<listItems.count {
                if currentList.isEmpty {
                    currentList.append(listItems[i])
                } else {
                    let prevEnd = currentList.last!.0.location + currentList.last!.0.length
                    let currStart = listItems[i].0.location
                    
                    if currStart == prevEnd + 1 { // 连续的
                        currentList.append(listItems[i])
                    } else {
                        lists.append(currentList)
                        currentList = [listItems[i]]
                    }
                }
            }
            
            if !currentList.isEmpty {
                lists.append(currentList)
            }
            
            // 处理每个列表
            for list in lists.reversed() {
                guard let firstItem = list.first, let lastItem = list.last else { continue }
                
                let startLocation = firstItem.0.location
                let endLocation = lastItem.0.location + lastItem.0.length
                let listRange = NSRange(location: startLocation, length: endLocation - startLocation)
                
                let itemsHTML = list.map { "<li>\($0.1)</li>" }.joined(separator: "\n")
                let listHTML = "<\(listType)>\n\(itemsHTML)\n</\(listType)>"
                
                if let range = Range(listRange, in: processed) {
                    processed.replaceSubrange(range, with: listHTML)
                }
            }
            
            return processed
        }
        
        private func processHorizontalRules(_ html: String) -> String {
            return html.replacingOccurrences(
                of: "^[-*_]{3,}$",
                with: "<hr>",
                options: .regularExpression
            )
        }
        
        private func processParagraphs(_ html: String) -> String {
            let lines = html.components(separatedBy: .newlines)
            var result: [String] = []
            var inParagraph = false
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmed.isEmpty {
                    if inParagraph {
                        result.append("</p>")
                        inParagraph = false
                    }
                } else if trimmed.hasPrefix("<") && isHTMLBlock(trimmed) {
                    if inParagraph {
                        result.append("</p>")
                        inParagraph = false
                    }
                    result.append(trimmed)
                } else {
                    if !inParagraph {
                        result.append("<p>")
                        inParagraph = true
                    } else {
                        result.append("<br>")
                    }
                    result.append(trimmed)
                }
            }
            
            if inParagraph {
                result.append("</p>")
            }
            
            return result.joined(separator: "\n")
        }
        
        private func isHTMLBlock(_ text: String) -> Bool {
            let htmlTags = ["<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<pre", "<blockquote", "<ul", "<ol", "<li", "<table", "<hr", "<div"]
            return htmlTags.contains { text.hasPrefix($0) }
        }
        
        private func processTaskLists(_ html: String) -> String {
            let pattern = "^- \\[([ xX])\\] (.+)$"
            let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            
            return regex.stringByReplacingMatches(
                in: html,
                options: [],
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<li class=\"task-list-item\"><input type=\"checkbox\" $1 disabled> $2</li>"
            )
        }
        
        private func processTables(_ html: String) -> String {
            // 简单的表格处理
            let tablePattern = "\\|(.+)\\|\\n\\|[-:\\s|]+\\|\\n((\\|.+\\|\\n)+)"
            let regex = try! NSRegularExpression(pattern: tablePattern, options: [.anchorsMatchLines])
            
            return regex.stringByReplacingMatches(
                in: html,
                options: [],
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<table>$1$2</table>"
            )
        }
        
        private func processFootnotes(_ html: String) -> String {
            // 脚注处理（简化版）
            let pattern = "\\[\\^(.+?)\\]"
            let regex = try! NSRegularExpression(pattern: pattern, options: [])
            
            return regex.stringByReplacingMatches(
                in: html,
                options: [],
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<sup class=\"footnote-ref\">$1</sup>"
            )
        }
        
        private func processMathExpressions(_ html: String) -> String {
            // 行内数学公式
            var processed = html.replacingOccurrences(
                of: "\\$([^$]+?)\\$",
                with: "<span class=\"math-inline\">$1</span>",
                options: .regularExpression
            )
            
            // 块级数学公式
            processed = processed.replacingOccurrences(
                of: "\\$\\$([\\s\\S]+?)\\$\\$",
                with: "<div class=\"math-block\">$1</div>",
                options: .regularExpression
            )
            
            return processed
        }
        
        private func processBidirectionalLinks(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
            let pattern = "\\[\\[([^\\]]+)\\]\\]"
            let regex = try! NSRegularExpression(pattern: pattern, options: [])
            
            let matches = regex.matches(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown))
            var processed = markdown
            
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: markdown) {
                    let content = String(markdown[range])
                    let fullRange = Range(match.range, in: markdown)!
                    
                    let parts = content.components(separatedBy: "|")
                    let target = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let display = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : target
                    
                    let linkHTML = createBidirectionalLinkHTML(target: target, display: display, context: context)
                    processed.replaceSubrange(fullRange, with: linkHTML)
                }
            }
            
            return processed
        }
        
        private func createBidirectionalLinkHTML(target: String, display: String, context: NSManagedObjectContext? = nil) -> String {
            let linkClass = "wikilink"
            let escapedTarget = target.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            return "<a href=\"#\" class=\"\(linkClass)\" data-target=\"\(target)\" onclick=\"handleWikiLink('\(escapedTarget)'); return false;\">\(display)</a>"
        }
        
        private func escapeHTML(_ string: String) -> String {
            return string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
        }
        
        private func wrapInHTML(_ html: String) -> String {
            return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Markdown Preview</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 20px;
                    background: #fff;
                }
                .markdown-body {
                    max-width: 900px;
                    margin: 0 auto;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3em; }
                p { margin-top: 0; margin-bottom: 16px; }
                code {
                    font-family: SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace;
                    background: #f6f8fa;
                    padding: 0.2em 0.4em;
                    margin: 0;
                    font-size: 85%;
                    border-radius: 3px;
                }
                pre {
                    background: #f6f8fa;
                    padding: 16px;
                    border-radius: 6px;
                    overflow: auto;
                    margin-bottom: 16px;
                }
                blockquote {
                    margin: 0 0 16px 0;
                    padding: 0 16px;
                    border-left: 4px solid #dfe2e5;
                    color: #6a737d;
                }
            </style>
            <script>
                function handleWikiLink(target) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.linkHandler) {
                        window.webkit.messageHandlers.linkHandler.postMessage({
                            target: target,
                            type: 'note'
                        });
                    }
                }
            </script>
        </head>
        <body>
            <div class="markdown-body">
                \(html)
            </div>
        </body>
        </html>
        """
        }
    }
}
