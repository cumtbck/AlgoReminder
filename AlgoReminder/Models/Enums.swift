import Foundation

// MARK: - 复习状态枚举
enum ReviewStatus: String, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case skipped = "skipped"
    case postponed = "postponed"
    
    var displayName: String {
        switch self {
        case .pending: return "待复习"
        case .completed: return "已完成"
        case .skipped: return "已跳过"
        case .postponed: return "已推迟"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .completed: return "green"
        case .skipped: return "gray"
        case .postponed: return "blue"
        }
    }
}

// MARK: - 复习间隔等级枚举
enum ReviewIntervalLevel: Int16, CaseIterable {
    case first = 1      // 第1次复习：1天后
    case second = 2     // 第2次复习：3天后
    case third = 3      // 第3次复习：7天后
    case fourth = 4     // 第4次复习：14天后
    case fifth = 5      // 第5次复习：30天后
    case sixth = 6      // 第6次复习：60天后
    case seventh = 7    // 第7次复习：120天后
    case mastered = 8   // 已掌握：180天后
    
    var intervalDays: Int {
        switch self {
        case .first: return 1
        case .second: return 3
        case .third: return 7
        case .fourth: return 14
        case .fifth: return 30
        case .sixth: return 60
        case .seventh: return 120
        case .mastered: return 180
        }
    }
    
    var displayName: String {
        switch self {
        case .first: return "第1次复习"
        case .second: return "第2次复习"
        case .third: return "第3次复习"
        case .fourth: return "第4次复习"
        case .fifth: return "第5次复习"
        case .sixth: return "第6次复习"
        case .seventh: return "第7次复习"
        case .mastered: return "已掌握"
        }
    }
}

// MARK: - 掌握程度枚举
enum MasteryLevel: Int16, CaseIterable {
    case notLearned = 0    // 未学习
    case learning = 1       // 学习中
    case familiar = 2      // 熟悉
    case proficient = 3    // 熟练
    case advanced = 4      // 进阶
    case mastered = 5      // 精通
    
    var displayName: String {
        switch self {
        case .notLearned: return "未学习"
        case .learning: return "学习中"
        case .familiar: return "熟悉"
        case .proficient: return "熟练"
        case .advanced: return "进阶"
        case .mastered: return "精通"
        }
    }
    
    var color: String {
        switch self {
        case .notLearned: return "gray"
        case .learning: return "red"
        case .familiar: return "orange"
        case .proficient: return "blue"
        case .advanced: return "green"
        case .mastered: return "mint"
        }
    }
    
    var progress: Float {
        Float(self.rawValue) / Float(MasteryLevel.mastered.rawValue)
    }
}

// MARK: - 难度等级枚举
enum DifficultyLevel: String, CaseIterable {
    case easy = "简单"
    case medium = "中等"
    case hard = "困难"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
    
    var weight: Float {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.0
        }
    }
}

// MARK: - 笔记类型枚举
enum NoteType: String, CaseIterable {
    case general = "general"
    case solution = "solution"
    case analysis = "analysis"
    case summary = "summary"
    case mistake = "mistake"
    case insight = "insight"
    
    var displayName: String {
        switch self {
        case .general: return "通用笔记"
        case .solution: return "解题思路"
        case .analysis: return "复杂度分析"
        case .summary: return "知识点总结"
        case .mistake: return "错题分析"
        case .insight: return "学习心得"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "note.text"
        case .solution: return "lightbulb"
        case .analysis: return "chart.xyaxis.line"
        case .summary: return "doc.text"
        case .mistake: return "exclamationmark.triangle"
        case .insight: return "brain.head.profile"
        }
    }
}

// MARK: - 学习路径状态枚举
enum LearningPathStatus: String, CaseIterable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .active: return "进行中"
        case .completed: return "已完成"
        case .paused: return "已暂停"
        case .archived: return "已归档"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .completed: return "blue"
        case .paused: return "orange"
        case .archived: return "gray"
        }
    }
}

// MARK: - 搜索结果类型枚举
enum SearchContentType: String, CaseIterable {
    case problem = "problem"
    case note = "note"
    case algorithm = "algorithm"
    case dataStructure = "dataStructure"
    
    var displayName: String {
        switch self {
        case .problem: return "题目"
        case .note: return "笔记"
        case .algorithm: return "算法"
        case .dataStructure: return "数据结构"
        }
    }
    
    var icon: String {
        switch self {
        case .problem: return "doc.text"
        case .note: return "note.text"
        case .algorithm: return "function"
        case .dataStructure: return "tree"
        }
    }
}

// MARK: - 排序方式枚举
enum SortOption: String, CaseIterable {
    case relevance = "relevance"
    case difficulty = "difficulty"
    case mastery = "mastery"
    case lastPracticed = "lastPracticed"
    case title = "title"
    case frequency = "frequency"
    case createdAt = "createdAt"
    
    var displayName: String {
        switch self {
        case .relevance: return "相关性"
        case .difficulty: return "难度"
        case .mastery: return "掌握度"
        case .lastPracticed: return "最后练习"
        case .title: return "标题"
        case .frequency: return "频率"
        case .createdAt: return "创建时间"
        }
    }
}

// MARK: - 推荐原因枚举
enum RecommendationReason: String, CaseIterable {
    case weakMastery = "weakMastery"
    case longTimeNoPractice = "longTimeNoPractice"
    case highFrequency = "highFrequency"
    case similarToWeakArea = "similarToWeakArea"
    case learningPathProgression = "learningPathProgression"
    case randomExploration = "randomExploration"
    
    var displayName: String {
        switch self {
        case .weakMastery: return "掌握度较低，建议加强练习"
        case .longTimeNoPractice: return "很久未练习，需要复习巩固"
        case .highFrequency: return "高频题目，值得重点掌握"
        case .similarToWeakArea: return "与弱点区域相似，建议练习"
        case .learningPathProgression: return "学习路径进阶题目"
        case .randomExploration: return "探索新知识点"
        }
    }
    
    var priority: Int {
        switch self {
        case .weakMastery: return 10
        case .longTimeNoPractice: return 8
        case .similarToWeakArea: return 7
        case .highFrequency: return 6
        case .learningPathProgression: return 5
        case .randomExploration: return 3
        }
    }
}

// MARK: - 置信度等级枚举
enum ConfidenceLevel: Int16, CaseIterable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case high = 4
    case veryHigh = 5
    
    var displayName: String {
        switch self {
        case .veryLow: return "毫无信心"
        case .low: return "有点印象"
        case .medium: return "基本掌握"
        case .high: return "比较熟练"
        case .veryHigh: return "完全掌握"
        }
    }
    
    var color: String {
        switch self {
        case .veryLow: return "red"
        case .low: return "orange"
        case .medium: return "yellow"
        case .high: return "green"
        case .veryHigh: return "mint"
        }
    }
}