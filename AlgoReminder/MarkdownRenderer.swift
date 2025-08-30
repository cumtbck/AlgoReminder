import Foundation
import WebKit
import CoreData

class MarkdownRenderer: NSObject, ObservableObject {
    static let shared = MarkdownRenderer()
    
    private override init() {}
    
    func renderMarkdown(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
        // 调试信息
        print("开始渲染 Markdown: \(markdown.count) 字符")
        
        if markdown.isEmpty {
            return "<html><body><p>笔记内容为空</p></body></html>"
        }
        
        // 保存原始 markdown 以便调试
        let originalMarkdown = markdown
        var html = markdown
        
        // Process bidirectional links first (before other markdown processing)
        html = processBidirectionalLinks(html, context: context)
        
        // Basic markdown to HTML conversion
        html = escapeHTML(html)
        
        // 处理代码块 (必须在其他处理之前进行，以避免内部内容被错误处理)
        let codeBlockPattern = "```([a-zA-Z0-9+]*)\\n([\\s\\S]*?)```"
        let codeBlockRegex = try! NSRegularExpression(pattern: codeBlockPattern, options: [])
        
        var lastMatchEnd = 0
        var processedSegments: [String] = []
        
        let matches = codeBlockRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        for match in matches {
            if let range = Range(match.range, in: html),
               let langRange = Range(match.range(at: 1), in: html),
               let codeRange = Range(match.range(at: 2), in: html) {
                
                // 添加代码块前的文本
                let startIndex = html.index(html.startIndex, offsetBy: lastMatchEnd)
                let endIndex = range.lowerBound
                if startIndex < endIndex {
                    processedSegments.append(String(html[startIndex..<endIndex]))
                }
                
                // 处理代码块
                let language = String(html[langRange])
                let code = String(html[codeRange])
                
                let codeHtml = "<pre><code class=\"language-\(language)\">\(code)</code></pre>"
                processedSegments.append(codeHtml)
                
                lastMatchEnd = html.distance(from: html.startIndex, to: range.upperBound)
            }
        }
        
        // 添加最后一部分
        if lastMatchEnd < html.count {
            let startIndex = html.index(html.startIndex, offsetBy: lastMatchEnd)
            processedSegments.append(String(html[startIndex...]))
        }
        
        // 重新组合处理过代码块的文本
        if !matches.isEmpty {
            html = processedSegments.joined()
        }
        
        // Headers
        html = html.replacingOccurrences(of: "^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^##### (.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^###### (.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        
        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: "_(.+?)_", with: "<em>$1</em>", options: .regularExpression)
        
        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+?)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Links
        html = html.replacingOccurrences(of: "\\[(.+?)\\]\\((.+?)\\)", with: "<a href=\"$2\" target=\"_blank\">$1</a>", options: .regularExpression)
        
        // Images
        html = html.replacingOccurrences(of: "!\\[(.+?)\\]\\((.+?)\\)", with: "<img src=\"$2\" alt=\"$1\" style=\"max-width: 100%; height: auto;\"/>", options: .regularExpression)
        
        // Blockquotes (multi-line)
        let blockquotePattern = "(^> .+\\n)+"
        let blockquoteRegex = try! NSRegularExpression(pattern: blockquotePattern, options: [])
        let blockquoteMatches = blockquoteRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        for match in blockquoteMatches.reversed() {
            if let range = Range(match.range, in: html) {
                let blockquoteText = String(html[range])
                let lines = blockquoteText.components(separatedBy: .newlines)
                
                let processedLines = lines.map { line -> String in
                    if line.hasPrefix("> ") {
                        return String(line.dropFirst(2))
                    }
                    return line
                }.filter { !$0.isEmpty }.joined(separator: "<br>")
                
                let replacement = "<blockquote>\(processedLines)</blockquote>"
                html.replaceSubrange(range, with: replacement)
            }
        }
        
        // Horizontal rules
        html = html.replacingOccurrences(of: "^[-*_]{3,}$", with: "<hr>", options: .regularExpression)
        
        // Lists - Unordered
        html = processLists(html, pattern: "^- (.+)$", listType: "ul")
        
        // Lists - Ordered
        html = processLists(html, pattern: "^\\d+\\. (.+)$", listType: "ol")
        
        // Paragraphs
        let lines = html.components(separatedBy: CharacterSet.newlines)
        var paragraphLines: [String] = []
        var inParagraph = false
        var inHTML = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                if inParagraph {
                    paragraphLines.append("</p>")
                    inParagraph = false
                }
            } else if trimmedLine.hasPrefix("<") && (
                    trimmedLine.hasPrefix("<h1>") || 
                    trimmedLine.hasPrefix("<h2>") || 
                    trimmedLine.hasPrefix("<h3>") || 
                    trimmedLine.hasPrefix("<h4>") || 
                    trimmedLine.hasPrefix("<h5>") || 
                    trimmedLine.hasPrefix("<h6>") || 
                    trimmedLine.hasPrefix("<pre>") || 
                    trimmedLine.hasPrefix("<blockquote>") || 
                    trimmedLine.hasPrefix("<ul>") || 
                    trimmedLine.hasPrefix("<ol>") || 
                    trimmedLine.hasPrefix("<hr>") ||
                    trimmedLine.hasPrefix("<table>")
                  ) {
                if inParagraph {
                    paragraphLines.append("</p>")
                    inParagraph = false
                }
                paragraphLines.append(trimmedLine)
                
                if trimmedLine.starts(with: "<pre") {
                    inHTML = true
                }
                
                if trimmedLine.hasSuffix("</pre>") {
                    inHTML = false
                }
            } else if inHTML {
                paragraphLines.append(trimmedLine)
            } else if !trimmedLine.hasPrefix("<") && !inParagraph {
                paragraphLines.append("<p>")
                paragraphLines.append(trimmedLine)
                inParagraph = true
            } else if !trimmedLine.hasPrefix("<") && inParagraph {
                paragraphLines.append("<br>")
                paragraphLines.append(trimmedLine)
            } else {
                paragraphLines.append(trimmedLine)
            }
        }
        
        if inParagraph {
            paragraphLines.append("</p>")
        }
        
        html = paragraphLines.joined(separator: "\n")
        
        // Add CSS styling
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                :root {
                    color-scheme: light dark;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 20px;
                    background-color: #ffffff;
                    font-size: 16px;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e0e0e0;
                        background-color: #202020;
                    }
                }
                
                h1, h2, h3, h4, h5, h6 {
                    color: #2c3e50;
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                
                @media (prefers-color-scheme: dark) {
                    h1, h2, h3, h4, h5, h6 {
                        color: #e0e0e0;
                    }
                }
                
                h1 { font-size: 2em; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
                h2 { font-size: 1.5em; border-bottom: 1px solid #ecf0f1; padding-bottom: 8px; }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1.1em; }
                h5 { font-size: 1em; }
                h6 { font-size: 0.9em; }
                
                @media (prefers-color-scheme: dark) {
                    h1 { border-bottom-color: #1a5f8c; }
                    h2 { border-bottom-color: #3c3c3c; }
                }
                
                p { margin-bottom: 16px; }
                
                code {
                    background-color: #f8f9fa;
                    padding: 2px 4px;
                    border-radius: 3px;
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                    font-size: 0.9em;
                }
                
                @media (prefers-color-scheme: dark) {
                    code {
                        background-color: #2d2d2d;
                    }
                }
                
                pre {
                    background-color: #f8f9fa;
                    border: 1px solid #e9ecef;
                    border-radius: 4px;
                    padding: 16px;
                    overflow-x: auto;
                    margin-bottom: 16px;
                }
                
                pre code {
                    background-color: transparent;
                    padding: 0;
                    border-radius: 0;
                    font-size: 1em;
                    white-space: pre;
                }
                
                @media (prefers-color-scheme: dark) {
                    pre {
                        background-color: #2d2d2d;
                        border-color: #3c3c3c;
                    }
                }
                
                blockquote {
                    border-left: 4px solid #3498db;
                    padding-left: 16px;
                    margin: 16px 0;
                    color: #7f8c8d;
                    font-style: italic;
                }
                
                @media (prefers-color-scheme: dark) {
                    blockquote {
                        border-left-color: #1a5f8c;
                        color: #a0a0a0;
                    }
                }
                
                ul, ol {
                    margin-bottom: 16px;
                    padding-left: 24px;
                }
                
                li {
                    margin-bottom: 4px;
                }
                
                a {
                    color: #3498db;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                @media (prefers-color-scheme: dark) {
                    a {
                        color: #63b3ed;
                    }
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                    margin: 8px 0;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid #e9ecef;
                    margin: 24px 0;
                }
                
                @media (prefers-color-scheme: dark) {
                    hr {
                        border-top-color: #3c3c3c;
                    }
                }
                
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin-bottom: 16px;
                }
                
                th, td {
                    border: 1px solid #e9ecef;
                    padding: 8px 12px;
                    text-align: left;
                }
                
                th {
                    background-color: #f8f9fa;
                    font-weight: 600;
                }
                
                @media (prefers-color-scheme: dark) {
                    th, td {
                        border-color: #3c3c3c;
                    }
                    
                    th {
                        background-color: #2d2d2d;
                    }
                }
                
                /* Bidirectional Links Styles */
                .bidirectional-link {
                    color: #3498db;
                    text-decoration: none;
                    border-bottom: 1px dotted #3498db;
                    padding: 0 2px;
                    border-radius: 2px;
                    transition: all 0.2s ease;
                }
                
                .bidirectional-link:hover {
                    background-color: #3498db;
                    color: white;
                    text-decoration: none;
                    border-bottom: none;
                }
                
                @media (prefers-color-scheme: dark) {
                    .bidirectional-link {
                        color: #63b3ed;
                        border-bottom-color: #63b3ed;
                    }
                    
                    .bidirectional-link:hover {
                        background-color: #1a5f8c;
                    }
                }
                
                .problem-link {
                    color: #e74c3c;
                    border-bottom-color: #e74c3c;
                }
                
                .problem-link:hover {
                    background-color: #e74c3c;
                }
                
                @media (prefers-color-scheme: dark) {
                    .problem-link {
                        color: #f56565;
                        border-bottom-color: #f56565;
                    }
                    
                    .problem-link:hover {
                        background-color: #9b2c2c;
                    }
                }
                
                .note-link {
                    color: #9b59b6;
                    border-bottom-color: #9b59b6;
                }
                
                .note-link:hover {
                    background-color: #9b59b6;
                }
                
                @media (prefers-color-scheme: dark) {
                    .note-link {
                        color: #d53f8c;
                        border-bottom-color: #d53f8c;
                    }
                    
                    .note-link:hover {
                        background-color: #702459;
                    }
                }
                
                .broken-link {
                    color: #95a5a6;
                    border-bottom-color: #95a5a6;
                    border-bottom-style: dashed;
                }
                
                .broken-link:hover {
                    background-color: #95a5a6;
                }
                
                @media (prefers-color-scheme: dark) {
                    .broken-link {
                        color: #718096;
                        border-bottom-color: #718096;
                    }
                    
                    .broken-link:hover {
                        background-color: #4a5568;
                    }
                }
            </style>
            
            <script>
                function handleBidirectionalLinkClick(target, type) {
                    // Send message to Swift app
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.linkHandler) {
                        window.webkit.messageHandlers.linkHandler.postMessage({
                            target: target,
                            type: type
                        });
                    }
                }
                
                // 检测系统深色模式变化并适应
                window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
                    const newColorScheme = e.matches ? 'dark' : 'light';
                    document.documentElement.style.colorScheme = newColorScheme;
                });
            </script>
        </head>
        <body>
            <!-- 调试信息 -->
            <div class="note-debug">
                Markdown 长度: \(originalMarkdown.count) 字符
                <br>
                HTML 长度: \(html.count) 字符
                <br>
                渲染时间: \(Date())
            </div>
            
            \(html)
        </body>
        </html>
        """
        
        print("完成渲染 HTML: \(styledHTML.count) 字符")
        return styledHTML
    }
    
    private func processLists(_ html: String, pattern: String, listType: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(html.startIndex..., in: html)
        
        // 找到所有匹配的列表项
        let matches = regex.matches(in: html, options: [], range: nsRange)
        if matches.isEmpty {
            return html
        }
        
        var processedHTML = html
        var listItems: [NSRange] = []
        var listItemContents: [String] = []
        
        // 收集所有列表项
        for match in matches {
            if let range = Range(match.range, in: html),
               let contentRange = Range(match.range(at: 1), in: html) {
                listItems.append(match.range)
                listItemContents.append(String(html[contentRange]))
            }
        }
        
        // 识别连续的列表项，并将它们分组
        var currentList: [NSRange] = []
        var allLists: [[NSRange]] = []
        
        for i in 0..<listItems.count {
            if currentList.isEmpty {
                currentList.append(listItems[i])
            } else {
                let previousRange = currentList.last!
                let currentRange = listItems[i]
                
                // 检查当前列表项是否紧跟在前一个列表项之后
                let previousEnd = previousRange.location + previousRange.length
                let lineBreakLength = 1 // 假设换行符长度为1
                
                if currentRange.location == previousEnd + lineBreakLength {
                    currentList.append(currentRange)
                } else {
                    // 开始新的列表
                    allLists.append(currentList)
                    currentList = [currentRange]
                }
            }
        }
        
        if !currentList.isEmpty {
            allLists.append(currentList)
        }
        
        // 从后向前处理所有列表，以避免索引变化问题
        for list in allLists.reversed() {
            // 计算整个列表的范围
            let startLocation = list.first!.location
            let endLocation = list.last!.location + list.last!.length
            let fullListRange = NSRange(location: startLocation, length: endLocation - startLocation)
            
            // 提取所有列表项的内容
            var listItemsHTML = ""
            for i in 0..<list.count {
                let rangeInOriginal = list[i]
                if let range = Range(rangeInOriginal, in: html),
                   let contentRange = Range(regex.firstMatch(in: html, options: [], range: rangeInOriginal)!.range(at: 1), in: html) {
                    let content = String(html[contentRange])
                    listItemsHTML += "<li>\(content)</li>\n"
                }
            }
            
            // 创建完整的列表HTML
            let listHTML = "<\(listType)>\n\(listItemsHTML)</\(listType)>"
            
            // 替换原文本中的列表项
            if let range = Range(fullListRange, in: processedHTML) {
                processedHTML.replaceSubrange(range, with: listHTML)
            }
        }
        
        return processedHTML
    }
    
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    func extractTitleFromMarkdown(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("# ") {
                return String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Untitled Note"
    }
    
    // MARK: - Bidirectional Links Processing
    
    private func processBidirectionalLinks(_ markdown: String, context: NSManagedObjectContext? = nil) -> String {
        // Pattern to match [[link text]] or [[link text|display text]]
        let linkPattern = "\\[\\[([^\\]]+)\\]\\]"
        let regex = try! NSRegularExpression(pattern: linkPattern, options: [])
        
        let matches = regex.matches(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown))
        
        var processedMarkdown = markdown
        
        // Process matches in reverse order to maintain correct string indices
        for match in matches.reversed() {
            if let range = Range(match.range(at: 1), in: markdown) {
                let linkContent = String(markdown[range])
                let fullMatchRange = Range(match.range, in: markdown)!
                
                // Parse link content for display text and target
                let components = linkContent.components(separatedBy: "|")
                let target = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let displayText = components.count > 1 ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : target
                
                // Create the replacement HTML
                let replacement = createBidirectionalLinkHTML(target: target, displayText: displayText, context: context)
                processedMarkdown.replaceSubrange(fullMatchRange, with: replacement)
            }
        }
        
        return processedMarkdown
    }
    
    private func createBidirectionalLinkHTML(target: String, displayText: String, context: NSManagedObjectContext? = nil) -> String {
        // Check if the target exists as a problem or note
        let problem = findProblemByTitle(target, context: context)
        let note = findNoteByTitle(target, context: context)
        
        let linkClass: String
        let dataAttributes: String
        let linkType: String
        
        if problem != nil {
            linkClass = "bidirectional-link problem-link"
            dataAttributes = "data-type=\"problem\" data-target=\"\(target)\""
            linkType = "problem"
        } else if note != nil {
            linkClass = "bidirectional-link note-link"
            dataAttributes = "data-type=\"note\" data-target=\"\(target)\""
            linkType = "note"
        } else {
            linkClass = "bidirectional-link broken-link"
            dataAttributes = "data-type=\"broken\" data-target=\"\(target)\""
            linkType = "broken"
        }
        
        // Add hover tooltip with creation suggestion for broken links
        let tooltip = linkType == "broken" ? " title=\"点击创建 \(target)\"" : ""
        
        return """
        <a href="#" class="\(linkClass)" \(dataAttributes)\(tooltip) onclick="handleBidirectionalLinkClick('\(target)', '\(linkType)'); return false;">
            \(displayText)
        </a>
        """
    }
    
    private func findProblemByTitle(_ title: String, context: NSManagedObjectContext? = nil) -> Problem? {
        guard let context = context else { return nil }
        
        let request: NSFetchRequest<Problem> = Problem.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", title)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    private func findNoteByTitle(_ title: String, context: NSManagedObjectContext? = nil) -> Note? {
        guard let context = context else { return nil }
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", title)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
}