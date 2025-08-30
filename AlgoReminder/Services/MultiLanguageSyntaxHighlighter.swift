import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// 轻量多语言代码高亮（启发式）。
struct MultiLanguageSyntaxHighlighter {
    // 使用 NSColor 便于向 NSAttributedString 施加属性
    struct Theme {
        let keyword: NSColor
        let type: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        static let dark = Theme(keyword: .systemBlue,
                                 type: .systemTeal,
                                 string: .systemGreen,
                                 comment: .systemGray,
                                 number: .systemPurple)
        static let light = Theme(keyword: .systemBlue,
                                  type: .systemTeal,
                                  string: NSColor(calibratedRed: 163/255, green: 21/255, blue: 21/255, alpha: 1),
                                  comment: .systemGray,
                                  number: .systemPurple)
    }

    static func highlight(code: String, language rawLang: String?, colorScheme: ColorScheme? = nil, largeCodeFallbackThreshold: Int = 40_000) -> AttributedString {
        if code.isEmpty { return AttributedString("") }
        if code.count > largeCodeFallbackThreshold { return AttributedString(code) }
        let lang = canonicalLanguage(rawLang)
        let theme = (colorScheme == .light) ? Theme.light : Theme.dark
        let mutable = NSMutableAttributedString(string: code)

        func apply(pattern: String, options: NSRegularExpression.Options = [], color: NSColor) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            let range = NSRange(location: 0, length: mutable.length)
            regex.enumerateMatches(in: code, options: [], range: range) { match, _, _ in
                guard let m = match else { return }
                mutable.addAttribute(.foregroundColor, value: color, range: m.range)
            }
        }

        // 注释
        switch lang {
        case "python", "ruby", "shell", "bash":
            apply(pattern: "#.*$", options: [.anchorsMatchLines], color: theme.comment)
        default:
            apply(pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment) // 多行
            apply(pattern: "//.*$", options: [.anchorsMatchLines], color: theme.comment)
            apply(pattern: "#(?!![a-zA-Z]).*$", options: [.anchorsMatchLines], color: theme.comment)
        }

        // 字符串（含 Python 三引号）
        if lang == "python" { apply(pattern: "\"\"\"[\\s\\S]*?\"\"\"", color: theme.string) }
        apply(pattern: "\"([^\\\"\\n]|\\.)*\"", color: theme.string)
        apply(pattern: "'([^\\'\\n]|\\.)*'", color: theme.string)

        // 数字
        apply(pattern: "\\b[0-9]+(\\.[0-9]+)?\\b", color: theme.number)

        // 关键字 / 类型
        let kw = keywords(for: lang)
        if !kw.keywords.isEmpty {
            let pattern = "\\b(" + kw.keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")\\b"
            apply(pattern: pattern, color: theme.keyword)
        }
        if !kw.types.isEmpty {
            let pattern = "\\b(" + kw.types.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")\\b"
            apply(pattern: pattern, color: theme.type)
        }

        return AttributedString(mutable)
    }

    // MARK: - Helpers
    private struct KeywordSet { let keywords: [String]; let types: [String] }

    private static func canonicalLanguage(_ lang: String?) -> String {
        guard let l = lang?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !l.isEmpty else { return "plain" }
        switch l {
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "rb": return "ruby"
        case "c++", "hpp", "h++": return "cpp"
        case "sh", "zsh": return "shell"
        default: return l
        }
    }

    private static func keywords(for lang: String) -> KeywordSet {
        switch lang {
        case "swift":
            return KeywordSet(keywords: ["func","let","var","if","else","for","while","return","struct","class","enum","protocol","extension","import","guard","where","in","repeat","do","catch","try","throws","rethrows","associatedtype","case","switch","defer","init","subscript","static","break","continue","fallthrough","as","is","operator","precedence","inout","async","await","actor"],
                               types: ["Int","String","Double","Float","Bool","Array","Dictionary","Set","Optional","Result","Data","URL","Task"])
        case "python":
            return KeywordSet(keywords: ["def","class","if","elif","else","for","while","return","import","from","as","with","try","except","finally","raise","True","False","None","lambda","yield","global","nonlocal","assert","pass","break","continue","async","await"], types: ["int","str","float","bool","list","dict","set","tuple","Exception","BaseException","object"])
        case "javascript", "typescript":
            return KeywordSet(keywords: ["function","if","else","for","while","return","import","from","export","default","class","extends","constructor","super","this","new","let","const","var","try","catch","finally","throw","switch","case","break","continue","of","in","async","await","yield"], types: ["String","Number","Boolean","Array","Map","Set","Promise","Date","RegExp","Error","any","unknown","never","void"])
        case "java":
            return KeywordSet(keywords: ["class","interface","enum","public","private","protected","if","else","for","while","switch","case","break","continue","return","package","import","throws","throw","try","catch","finally","static","final","abstract","implements","extends","new","this","super","synchronized","volatile"], types: ["int","long","double","float","boolean","char","byte","short","String","List","Map","Set","Optional","void"])
        case "cpp", "c++":
            return KeywordSet(keywords: ["if","else","for","while","switch","case","break","continue","return","class","struct","enum","namespace","using","public","private","protected","virtual","override","template","typename","const","constexpr","volatile","static","inline","friend","operator","new","delete","this","try","catch","throw"], types: ["int","long","double","float","bool","char","void","std","size_t","string","vector","map","auto"])
        case "c":
            return KeywordSet(keywords: ["if","else","for","while","switch","case","break","continue","return","struct","enum","typedef","sizeof","const","volatile","static","inline","extern","goto"], types: ["int","long","double","float","bool","char","void","size_t"])
        case "go":
            return KeywordSet(keywords: ["func","if","else","for","range","switch","case","break","continue","return","import","package","type","struct","interface","go","defer","select","map","chan","const","var"], types: ["int","int64","float64","string","bool","error","byte","rune","map","chan"])
        case "rust":
            return KeywordSet(keywords: ["fn","let","mut","if","else","for","while","loop","match","use","mod","pub","crate","super","self","impl","trait","enum","struct","return","as","move","ref","unsafe","async","await","macro_rules"], types: ["i32","i64","u32","u64","usize","isize","String","Vec","Option","Result","Box"])
        case "kotlin":
            return KeywordSet(keywords: ["fun","val","var","if","else","for","while","return","import","package","class","interface","object","companion","when","try","catch","finally","throw","as","is","in","this","super","constructor","init","override","data","sealed","suspend"], types: ["Int","Long","Double","Float","Boolean","Char","String","List","Map","Set","Array"])
        case "ruby":
            return KeywordSet(keywords: ["def","class","module","if","elsif","else","end","do","while","until","for","return","yield","self","nil","true","false","begin","rescue","ensure","require","include","extend","alias","super","unless","case","when","break","next","redo","retry"], types: ["String","Array","Hash","Integer","Float","Symbol","Object"])
        case "shell":
            return KeywordSet(keywords: ["if","then","fi","else","elif","for","while","in","do","done","case","esac","function","return","exit","export","local","unset"], types: [])
        default:
            return KeywordSet(keywords: [], types: [])
        }
    }
}
