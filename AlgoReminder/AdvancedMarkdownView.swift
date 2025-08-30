// AdvancedMarkdownView.swift
// 集成五项增强: 1) 代码高亮 2) 任务列表 3) 表格 4) 图片显示 5) 大文档分页/懒加载

import SwiftUI
import CoreData

#if canImport(Splash)
import Splash
#endif

/// 外部使用：传入原始 markdown 与可选 CoreData context；
/// onUpdateMarkdown 在任务列表复选框切换时回写更新后的 markdown。
struct AdvancedMarkdownView: View {
    let originalMarkdown: String
    let context: NSManagedObjectContext?
    var onLink: (String,String) -> Void
    var onUpdateMarkdown: (String) -> Void

    // 分页参数
    private let sectionCharThreshold = 8_000
    @State private var expandedSections: Set<Int> = []

    private var sections: [MarkdownSection] {
        MarkdownSection.split(markdown: originalMarkdown, threshold: sectionCharThreshold)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(Array(sections.enumerated()), id: \.offset) { (index, section) in
                    SectionView(section: section,
                                context: context,
                                onLink: onLink,
                                onUpdateMarkdown: handleSectionUpdate,
                                isCollapsed: isCollapsed(sectionIndex: index),
                                toggleCollapse: { toggleSection(index) })
                        .animation(.easeInOut(duration: 0.2), value: expandedSections)
                }
            }
            .padding([.horizontal, .top])
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func isCollapsed(sectionIndex: Int) -> Bool {
        // 初始：大文档只展开第一节
        if sections.count > 1 && sectionIndex != 0 {
            return !expandedSections.contains(sectionIndex)
        }
        return false
    }

    private func toggleSection(_ index: Int) {
        if expandedSections.contains(index) { expandedSections.remove(index) } else { expandedSections.insert(index) }
    }

    private func handleSectionUpdate(_ updated: String) {
        // 合并各节内容更新任务状态
        onUpdateMarkdown(updated)
    }
}

// MARK: - Section Model
enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case code(language: String?, content: String)
    case taskListItem(checked: Bool, text: String, originalLine: String)
    case paragraph(text: String)
    case table(headers: [String], rows: [[String]])
    case image(alt: String, url: String)
    case horizontalRule
    case raw(String)

    var id: String {
        switch self {
        case .heading(let l, let t): return "h-\(l)-\(t)"
        case .code(let lang, let content): return "code-\(lang ?? "none")-\(content.hashValue)"
        case .taskListItem(_, _, let orig): return "task-\(orig.hashValue)"
        case .paragraph(let text): return "p-\(text.hashValue)"
        case .table(let headers, let rows): return "table-\(headers.joined())-\(rows.count)"
        case .image(let alt, let url): return "img-\(alt)-\(url)"
        case .horizontalRule: return "hr"
        case .raw(let s): return "raw-\(s.hashValue)"
        }
    }
}

struct MarkdownSection: Identifiable {
    let id = UUID()
    let title: String?
    let rawText: String
    let blocks: [MarkdownBlock]

    static func split(markdown: String, threshold: Int) -> [MarkdownSection] {
        // 若整体不超限，单节处理
        if markdown.count <= threshold { return [MarkdownSection(title: nil, rawText: markdown, blocks: MarkdownParser.parseBlocks(from: markdown))] }
        // 以 H1/H2 作为分页
    // 简化换行分割，避免多行正则导致的编译问题
    let lines = markdown.components(separatedBy: CharacterSet.newlines)
        var sections: [MarkdownSection] = []
        var currentLines: [String] = []
        var currentTitle: String? = nil
        func flush() {
            guard !currentLines.isEmpty else { return }
            let text = currentLines.joined(separator: "\n")
            sections.append(MarkdownSection(title: currentTitle, rawText: text, blocks: MarkdownParser.parseBlocks(from: text)))
            currentLines = []
        }
        for line in lines {
            if line.hasPrefix("# ") || line.hasPrefix("## ") { // 作为新段落起点
                flush()
                currentTitle = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            }
            currentLines.append(line)
        }
        flush()
        return sections
    }
}

// MARK: - Parser
enum MarkdownParser {
    static func parseBlocks(from text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("```") { // code block
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                var contentLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    contentLines.append(lines[i]); i += 1
                }
                blocks.append(.code(language: lang.isEmpty ? nil : lang, content: contentLines.joined(separator: "\n")))
            } else if let heading = parseHeading(line) {
                blocks.append(heading)
            } else if isHorizontalRule(line) {
                blocks.append(.horizontalRule)
            } else if let (checked, text, orig) = parseTask(line) {
                blocks.append(.taskListItem(checked: checked, text: text, originalLine: orig))
            } else if isTableHeader(line) { // table detection
                var tableLines: [String] = [line]
                var j = i + 1
                while j < lines.count && lines[j].contains("|") && !lines[j].trimmingCharacters(in: .whitespaces).isEmpty {
                    tableLines.append(lines[j]); j += 1
                }
                if let table = buildTable(from: tableLines) {
                    blocks.append(table)
                    i = j - 1
                } else {
                    blocks.append(.paragraph(text: line))
                }
            } else if let image = parseImage(line) {
                blocks.append(image)
            } else if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // ignore empty -> paragraph separation
            } else { // paragraph grouping
                var paraLines: [String] = [line]
                var j = i + 1
                while j < lines.count && !lines[j].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !lines[j].hasPrefix("#") && !lines[j].hasPrefix("```") {
                    if parseTask(lines[j]) != nil || isTableHeader(lines[j]) || parseImage(lines[j]) != nil { break }
                    paraLines.append(lines[j]); j += 1
                }
                blocks.append(.paragraph(text: paraLines.joined(separator: "\n")))
                i = j - 1
            }
            i += 1
        }
        return blocks
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "#" else { return nil }
        let level = trimmed.prefix { $0 == "#" }.count
        guard level > 0 && level <= 6 else { return nil }
        let text = trimmed.drop(while: { $0 == "#" || $0 == " " })
        return .heading(level: level, text: String(text))
    }

    private static func parseTask(_ line: String) -> (Bool, String, String)? {
        let pattern = "^- \\[( |x|X)\\] (.+)$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
            let checkedRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            if let cr = Range(checkedRange, in: line), let tr = Range(textRange, in: line) {
                let checkedChar = line[cr]
                return (checkedChar.lowercased() == "x", String(line[tr]), line)
            }
        }
        return nil
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t == "---" || t == "***" || t == "___"
    }

    private static func parseImage(_ line: String) -> MarkdownBlock? {
        let pattern = "^!\\[([^\\]]*)\\]\\(([^\\)]+)\\)" // ![alt](url)
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)), match.range.location == 0 {
            if let altR = Range(match.range(at: 1), in: line), let urlR = Range(match.range(at: 2), in: line) {
                return .image(alt: String(line[altR]), url: String(line[urlR]))
            }
        }
        return nil
    }

    private static func isTableHeader(_ line: String) -> Bool {
        // 简单判断：包含 | 且至少两个分隔
        return line.contains("|") && line.split(separator: "|").count >= 2
    }

    private static func buildTable(from lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }
        let header = lines[0]
        let bodyLines = Array(lines.dropFirst())
        let headers = header.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var rows: [[String]] = []
        for l in bodyLines {
            let cols = l.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if cols.count == headers.count { rows.append(cols) }
        }
        guard !headers.isEmpty && !rows.isEmpty else { return nil }
        return .table(headers: headers, rows: rows)
    }
}

// MARK: - Views
private struct SectionView: View {
    let section: MarkdownSection
    let context: NSManagedObjectContext?
    var onLink: (String,String) -> Void
    var onUpdateMarkdown: (String) -> Void
    let isCollapsed: Bool
    let toggleCollapse: () -> Void

    @State private var localMarkdown: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title {
                HStack {
                    Button(action: toggleCollapse) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    }.buttonStyle(.plain)
                    Text(title).font(.title2.bold())
                }
            }
            if !isCollapsed {
                ForEach(section.blocks) { block in
                    blockView(block)
                }
            }
        }
        .onAppear { localMarkdown = section.rawText }
    }

    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text).font(fontForHeading(level))
        case .paragraph(let text):
            RichText(text: text, context: context, onLink: onLink)
        case .taskListItem(let checked, let text, let orig):
            TaskItemRow(checked: checked, text: text) { newValue in
                // 更新该行 markdown
                if let range = localMarkdown.range(of: orig) {
                    let replacement = "- [\(newValue ? "x" : " ")] \(text)"
                    localMarkdown.replaceSubrange(range, with: replacement)
                    onUpdateMarkdown(localMarkdown)
                }
            }
        case .code(let language, let content):
            CodeBlockView(language: language, code: content)
        case .table(let headers, let rows):
            TableView(headers: headers, rows: rows)
        case .image(let alt, let url):
            RemoteImageView(alt: alt, url: url)
        case .horizontalRule:
            Divider()
        case .raw(let s):
            Text(s).font(.body)
        }
    }

    private func fontForHeading(_ level: Int) -> Font {
        switch level { case 1: return .largeTitle.bold(); case 2: return .title.bold(); case 3: return .title2.bold(); case 4: return .title3.bold(); case 5: return .headline; default: return .subheadline }
    }
}

private struct TaskItemRow: View {
    @State var checked: Bool
    let text: String
    let onToggle: (Bool) -> Void
    var body: some View {
        HStack(alignment: .top) {
            Button(action: { checked.toggle(); onToggle(checked) }) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
            }.buttonStyle(.plain)
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(highlightedCode)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highlightedCode: AttributedString {
        #if canImport(Splash)
        if (language?.lowercased() == "swift" || language == nil) {
            // 仍然优先使用 Splash 对 Swift 提供更精细的高亮
            let highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: .sunset(withFont: .init(size: 14))))
            if let highlighted = try? highlighter.highlight(code) { return highlighted }
        }
        #endif
        // 其它语言使用自定义多语言高亮器
        return MultiLanguageSyntaxHighlighter.highlight(code: code, language: language)
    }
}

private struct TableView: View {
    let headers: [String]
    let rows: [[String]]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { ForEach(headers, id: \.self) { Text($0).font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading) } }
                .padding(6)
                .background(Color.secondary.opacity(0.15))
            ForEach(0..<rows.count, id: \.self) { i in
                HStack { ForEach(rows[i], id: \.self) { cell in Text(cell).frame(maxWidth: .infinity, alignment: .leading) } }
                    .padding(6)
                    .background(i.isMultiple(of: 2) ? Color.secondary.opacity(0.05) : Color.clear)
            }
            Divider().padding(.top, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }
}

private struct RemoteImageView: View {
    let alt: String
    let url: String
    var body: some View {
        if let valid = URL(string: url) {
            AsyncImage(url: valid) { phase in
                switch phase {
                case .empty: ProgressView().frame(height: 120)
                case .success(let image): image.resizable().scaledToFit().cornerRadius(4)
                case .failure(_): fallback
                @unknown default: fallback
                }
            }
        } else { fallback }
    }
    private var fallback: some View { Text("[Image: \(alt)]").italic().foregroundColor(.secondary) }
}

/// 富文本行内：处理双向链接 -> 自定义 scheme；利用 AttributedString full 解析
private struct RichText: View {
    let text: String
    let context: NSManagedObjectContext?
    var onLink: (String,String) -> Void
    @State private var attributed: AttributedString = ""

    var body: some View {
        Text(attributed).frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) { await build() }
            .environment(\._openURL, OpenURLAction { url in
                guard let scheme = url.scheme, scheme.hasPrefix("app-"), let host = url.host else { return .systemAction }
                let type = String(scheme.dropFirst("app-".count))
                let target = host.removingPercentEncoding ?? host
                onLink(target, type)
                return .handled
            })
    }

    private func build() async {
        let transformed = transformLinks(text)
        do {
            var opt = AttributedString.MarkdownParsingOptions()
            opt.interpretedSyntax = .full
            var att = try AttributedString(markdown: transformed, options: opt)
            // 简单行内 code 着色
            for run in att.runs where run.inlinePresentationIntent?.contains(.code) == true {
                var seg = AttributedString(att[run.range])
                seg.font = .system(.body, design: .monospaced)
                seg.backgroundColor = Color.secondary.opacity(0.08)
                att.replaceSubrange(run.range, with: seg)
            }
            attributed = att
        } catch { attributed = AttributedString(text) }
    }

    private func transformLinks(_ raw: String) -> String {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return raw }
        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        var result = raw
        for m in matches.reversed() {
            let inner = ns.substring(with: m.range(at: 1))
            let parts = inner.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            let target = parts[0]
            let display = parts.count > 1 ? parts[1] : target
            let kind = classify(target)
            let link = "[\(display)](app-\(kind)://\(target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target))"
            if let range = Range(m.range, in: result) { result.replaceSubrange(range, with: link) }
        }
        return result
    }

    private func classify(_ target: String) -> String {
        guard let context else { return "broken" }
        if findProblem(target, context: context) != nil { return "problem" }
        if findNote(target, context: context) != nil { return "note" }
        return "broken"
    }
    private func findProblem(_ title: String, context: NSManagedObjectContext) -> Problem? {
        let r: NSFetchRequest<Problem> = Problem.fetchRequest(); r.predicate = NSPredicate(format: "title == %@", title); r.fetchLimit = 1
        return try? context.fetch(r).first
    }
    private func findNote(_ title: String, context: NSManagedObjectContext) -> Note? {
        let r: NSFetchRequest<Note> = Note.fetchRequest(); r.predicate = NSPredicate(format: "title == %@", title); r.fetchLimit = 1
        return try? context.fetch(r).first
    }
}
