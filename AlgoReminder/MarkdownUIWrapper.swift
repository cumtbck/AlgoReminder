// MarkdownUIWrapper.swift
// 通过第三方库 MarkdownUI 提供更稳定的 Markdown 渲染，避免 WKWebView 进程终止。
// 使用条件：已通过 SPM 添加依赖 https://github.com/gonzalezreal/MarkdownUI

import Foundation
import SwiftUI
import CoreData

#if canImport(MarkdownUI)
import MarkdownUI

/// 将 [[target]] / [[target|显示名称]] 转换为可点击链接，并区分 problem / note / broken。
struct BidirectionalMarkdownView: View {
    let originalMarkdown: String
    let context: NSManagedObjectContext?
    let onLinkTap: ((String,String) -> Void)?

    private func classify(_ target: String) -> String {
        guard let context = context else { return "broken" }
        if findProblem(target, context: context) != nil { return "problem" }
        if findNote(target, context: context) != nil { return "note" }
        return "broken"
    }

    private func convert(_ markdown: String) -> String {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return markdown }
        let ns = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: ns.length))
        var result = markdown
        for m in matches.reversed() {
            let fullRange = m.range(at: 0)
            let innerRange = m.range(at: 1)
            let inner = ns.substring(with: innerRange)
            let parts = inner.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            let target = parts[0]
            let display = parts.count > 1 ? parts[1] : target
            let kind = classify(target)
            // 使用自定义 scheme 传递类型与目标
            let link = "[\(display)](app-\(kind)://\(target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target))"
            if let range = Range(fullRange, in: result) {
                result.replaceSubrange(range, with: link)
            }
        }
        return result
    }

    private var processed: String { convert(originalMarkdown) }

    var body: some View {
        Markdown(processed)
            .markdownTheme(.gitHub) // 先复用 GitHub 主题
            .markdownTextStyle() // 保留默认文本样式
            .environment(\._openURL, OpenURLAction { url in
                guard let scheme = url.scheme, scheme.hasPrefix("app-"), let host = url.host else { return .systemAction }
                let type = String(scheme.dropFirst("app-".count))
                let target = host.removingPercentEncoding ?? host
                onLinkTap?(target, type)
                return .handled
            })
            .modifier(BidirectionalLinkStyling())
    }

    // MARK: - CoreData helpers
    private func findProblem(_ title: String, context: NSManagedObjectContext) -> Problem? {
        let r: NSFetchRequest<Problem> = Problem.fetchRequest(); r.predicate = NSPredicate(format: "title == %@", title); r.fetchLimit = 1
        return try? context.fetch(r).first
    }
    private func findNote(_ title: String, context: NSManagedObjectContext) -> Note? {
        let r: NSFetchRequest<Note> = Note.fetchRequest(); r.predicate = NSPredicate(format: "title == %@", title); r.fetchLimit = 1
        return try? context.fetch(r).first
    }
}

/// 给不同类型的自定义链接加上颜色区分（通过解析 Markdown 生成后的 Text 视图层次较复杂；此处简单用 accentColor + underline 模式区分，后续可扩展为自定义 Renderer）。
private struct BidirectionalLinkStyling: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content
            .tint(colorScheme == .dark ? Color.accentColor : Color.blue)
    }
}

#endif
