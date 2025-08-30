// 修复编译错误：此前该文件混入了未封装的顶层片段与重复逻辑，
// 且项目实际已使用 `MarkdownRenderer` / `UnifiedMarkdownRenderer`。
// 保留一个空的占位符类以避免 Xcode 工程引用缺失。
// 如无需要，可在 Xcode 的项目文件里移除该文件引用后直接删除本文件。

import Foundation

@available(*, deprecated, message: "改用 MarkdownRenderer.shared 或 UnifiedMarkdownRenderer.shared")
final class ImprovedMarkdownRenderer {
    // 留空：旧实现已弃用。
}

