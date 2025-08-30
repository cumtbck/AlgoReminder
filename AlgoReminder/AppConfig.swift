import Foundation
import SwiftUI

class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    // MARK: - 基础配置
    // 题目来源配置
    let fixedSources = ["LeetCode", "ccf-csp", "luogu", "HackerRank", "Codeforces"]
    @Published var customSources: [String] = []
    
    // 难度等级配置
    let difficulties = ["简单", "中等", "困难"]
    
    // MARK: - LeetCode风格的多维度分类系统
    // 算法类型分类
    let algorithmTypes = [
        "动态规划", "贪心算法", "回溯算法", "二分查找", "排序算法", 
        "搜索算法", "数学", "位运算", "图论", "字符串匹配", "递归", "分治"
    ]
    
    // 数据结构分类
    let dataStructures = [
        "数组", "字符串", "链表", "栈", "队列", "树", "二叉树", "图", "堆", "哈希表", 
        "集合", "映射", "字典", "矩阵", "前缀树", "线段树", "并查集"
    ]
    
    // 技能标签
    let skillTags = [
        "双指针", "滑动窗口", "快速排序", "深度优先搜索", "广度优先搜索",
        "并查集", "前缀和", "差分数组", "单调栈", "单调队列", "KMP算法",
        "Manacher算法", "拓扑排序", "最短路径", "最小生成树", "网络流"
    ]
    
    // 公司标签
    let companies = [
        "Google", "Microsoft", "Amazon", "Apple", "Meta", "Netflix", "Tesla",
        "字节跳动", "阿里巴巴", "腾讯", "百度", "华为", "小米"
    ]
    
    // 题目类型标签
    let problemTypes = [
        "数组操作", "字符串处理", "链表操作", "树遍历", "图算法", "数学计算",
        "位运算", "递归问题", "排序问题", "搜索问题", "动态规划", "贪心选择"
    ]
    
    // 搜索范围配置
    let searchScopes = ["全部", "题目名称", "算法类型", "数据结构", "技能标签", "题目来源"]
    
    // MARK: - Obsidian风格的笔记系统
    let noteTypes = [
        "解题思路", "代码实现", "复杂度分析", "相关题目", "知识点总结", "错题分析"
    ]
    
    let noteTags = [
        "#算法", "#数据结构", "#动态规划", "#图论", "#字符串", "#数组",
        "#链表", "#树", "#数学", "#位运算", "#递归", "#分治"
    ]
    
    // MARK: - 初始化
    private init() {
        loadCustomSources()
    }
    
    // MARK: - 公共方法
    // 获取所有来源选项
    var allSources: [String] {
        return fixedSources + customSources + ["自定义"]
    }
    
    // 添加自定义来源
    func addCustomSource(_ source: String) {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customSources.contains(trimmedSource) && !fixedSources.contains(trimmedSource) else { return }
        
        customSources.append(trimmedSource)
        saveCustomSources()
    }
    
    // 删除自定义来源
    func removeCustomSource(_ source: String) {
        if let index = customSources.firstIndex(of: source) {
            customSources.remove(at: index)
            saveCustomSources()
        }
    }
    
    // 检查是否为固定来源
    func isFixedSource(_ source: String) -> Bool {
        return fixedSources.contains(source)
    }
    
    // 检查是否为自定义来源
    func isCustomSource(_ source: String) -> Bool {
        return customSources.contains(source)
    }
    
    // MARK: - 智能分类建议
    func getRecommendedTags(for problemTitle: String) -> [String] {
        let title = problemTitle.lowercased()
        var recommendedTags: [String] = []
        
        // 基于题目标题推荐标签
        if title.contains("数组") || title.contains("array") {
            recommendedTags.append("数组")
        }
        if title.contains("字符串") || title.contains("string") {
            recommendedTags.append("字符串")
        }
        if title.contains("链表") || title.contains("linked") {
            recommendedTags.append("链表")
        }
        if title.contains("树") || title.contains("tree") {
            recommendedTags.append("树")
        }
        if title.contains("图") || title.contains("graph") {
            recommendedTags.append("图")
        }
        if title.contains("动态规划") || title.contains("dp") {
            recommendedTags.append("动态规划")
        }
        if title.contains("排序") || title.contains("sort") {
            recommendedTags.append("排序算法")
        }
        
        return recommendedTags
    }
    
    func getSimilarProblems(for problem: (title: String, algorithmType: String?, dataStructure: String?), 
                            allProblems: [(title: String, algorithmType: String?, dataStructure: String?)]) -> [String] {
        var similarProblems: [String] = []
        
        for otherProblem in allProblems {
            guard otherProblem.title != problem.title else { continue }
            
            var similarityScore = 0
            
            // 算法类型相似性
            if let algo1 = problem.algorithmType, let algo2 = otherProblem.algorithmType, algo1 == algo2 {
                similarityScore += 3
            }
            
            // 数据结构相似性
            if let ds1 = problem.dataStructure, let ds2 = otherProblem.dataStructure, ds1 == ds2 {
                similarityScore += 2
            }
            
            // 标题相似性（简单的关键词匹配）
            let title1Words = problem.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let title2Words = otherProblem.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let commonWords = Set(title1Words).intersection(Set(title2Words))
            similarityScore += commonWords.count
            
            if similarityScore >= 3 {
                similarProblems.append(otherProblem.title)
            }
        }
        
        return similarProblems.sorted()
    }
    
    // MARK: - Private Methods
    
    private func saveCustomSources() {
        UserDefaults.standard.set(customSources, forKey: "CustomSources")
    }
    
    private func loadCustomSources() {
        if let savedSources = UserDefaults.standard.stringArray(forKey: "CustomSources") {
            customSources = savedSources
        }
    }
}

// MARK: - SwiftUI Environment Key
struct AppConfigKey: EnvironmentKey {
    static let defaultValue = AppConfig.shared
}

extension EnvironmentValues {
    var appConfig: AppConfig {
        get { self[AppConfigKey.self] }
        set { self[AppConfigKey.self] = newValue }
    }
}
