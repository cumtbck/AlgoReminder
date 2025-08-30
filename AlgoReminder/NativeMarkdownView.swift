// NativeMarkdownView.swift
// 使用系统 AttributedString(markdown:) 实现轻量级 Markdown 渲染
// 目的：避免 WKWebView 进程终止导致的空白，同时支持自定义 [[双向链接]]。

import SwiftUI
import CoreData

struct NativeMarkdownView: View {
    let markdown: String
    let context: NSManagedObjectContext?
    let onLink: (String,String) -> Void
    @State private var attributed: AttributedString = AttributedString("正在渲染…")
    @State private var renderError: String?

    var body: some View {
        ScrollView {
            if let renderError = renderError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解析失败: \(renderError)")
                        .foregroundColor(.red)
                    Text(markdown)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                // 用 Text 显示富文本
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal,.top])
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .environment(\._openURL, OpenURLAction { url in
            guard let scheme = url.scheme, scheme.hasPrefix("app-"), let host = url.host else { return .systemAction }
            let type = String(scheme.dropFirst("app-".count))
            let target = host.removingPercentEncoding ?? host
            onLink(target, type)
            return .handled
        })
        .task(id: markdown) {
            await render()
        }
    }

    private func render() async {
        do {
            let transformed = transformBidirectionalLinks(in: markdown)
            var parsingOptions = AttributedString.MarkdownParsingOptions()
            parsingOptions.interpretedSyntax = .full // 支持标题/列表/引用/代码块
            parsingOptions.allowsExtendedAttributes = true
            parsingOptions.appliesSourcePositionAttributes = false
            parsingOptions.failurePolicy = .returnPartiallyParsedIfPossible
            var att = try AttributedString(markdown: transformed, options: parsingOptions)
            // 针对 code / heading 做额外字体调整
            att = postProcess(att)
            await MainActor.run {
                self.attributed = att
                self.renderError = nil
            }
        } catch {
            await MainActor.run { self.renderError = error.localizedDescription }
        }
    }

    private func postProcess(_ input: AttributedString) -> AttributedString {
        // 仅处理行内 code；标题使用系统默认样式，避免访问不可用 API (presentationIntent.kind)。
        var output = AttributedString()
        for run in input.runs {
            var segment = AttributedString(input[run.range])
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                segment.inlinePresentationIntent = .code
                segment.font = .system(.body, design: .monospaced)
                segment.backgroundColor = Color.secondary.opacity(0.08)
            }
            output.append(segment)
        }
        return output
    }

    // 将 [[target]] 或 [[target|显示]] 转为标准 Markdown 链接 [显示](app-<type>://target)
    private func transformBidirectionalLinks(in text: String) -> String {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result = text
        for m in matches.reversed() {
            let inner = ns.substring(with: m.range(at: 1))
            let parts = inner.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            let target = parts[0]
            let display = parts.count > 1 ? parts[1] : target
            let kind = classify(target)
            let link = "[\(display)](app-\(kind)://\(target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target))"
            if let range = Range(m.range, in: result) {
                result.replaceSubrange(range, with: link)
            }
        }
        return result
    }

    private func classify(_ target: String) -> String {
        guard let context else { return "broken" }
        if findProblem(target, context: context) != nil { return "problem" }
        if findNote(target, context: context) != nil { return "note" }
        return "broken" }

    private func findProblem(_ title: String, context: NSManagedObjectContext) -> Problem? {
        let r: NSFetchRequest<Problem> = Problem.fetchRequest(); r.predicate = NSPredicate(format: "title == %@", title); r.fetchLimit = 1
        return try? context.fetch(r).first
    }
    private func findNote(_ title: String, context: NSManagedObjectContext) -> Note? {
        let r: NSFetchRequest<Note> = Note.fetchRequest(); r.predicate = NSPredicate(format: "title == %@", title); r.fetchLimit = 1
        return try? context.fetch(r).first
    }
}
