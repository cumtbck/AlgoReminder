import Foundation
import CoreData
import Cocoa
import UserNotifications

// MARK: - 搜索相关结构

struct SearchFilters {
    var contentType: SearchContentType = .problem
    var difficulty: DifficultyLevel? = nil
    var algorithmType: String? = nil
    var dataStructure: String? = nil
    var masteryLevel: MasteryLevel? = nil
    var tags: [String] = []
    var dateRange: DateInterval? = nil
    var sortBy: SortOption = .relevance
    var sortOrder: SortOrder = .descending
}

enum SortOrder: String, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "升序"
        case .descending: return "降序"
        }
    }
}

struct SearchResult {
    let id: UUID
    let type: SearchContentType
    let title: String
    let content: String
    let relevanceScore: Float
    let problem: Problem?
    let note: Note?
    let metadata: [String: String]
    
    init(problem: Problem, relevanceScore: Float) {
        self.id = problem.id ?? UUID()
        self.type = .problem
        self.title = problem.title ?? "未知题目"
        self.content = problem.algorithmType ?? ""
        self.relevanceScore = relevanceScore
        self.problem = problem
        self.note = nil
        self.metadata = [
            "algorithmType": problem.algorithmType ?? "",
            "dataStructure": problem.dataStructure ?? "",
            "difficulty": problem.difficulty ?? "",
            "source": problem.source ?? ""
        ]
    }
    
    init(note: Note, relevanceScore: Float) {
        self.id = note.id ?? UUID()
        self.type = .note
        self.title = note.title ?? "未知笔记"
        self.content = note.rawMarkdown ?? ""
        self.relevanceScore = relevanceScore
        self.problem = nil
        self.note = note
        self.metadata = [
            "noteType": note.noteType ?? "",
            "createdAt": note.createdAt?.ISO8601Format() ?? ""
        ]
    }
}

struct SearchSuggestion: Equatable {
    let text: String
    let type: SearchContentType
    let frequency: Int
    let context: String?
}

// MARK: - 推荐相关结构


// MARK: - 复习相关结构

struct ReviewSession {
    let id: UUID
    let date: Date
    let problemsReviewed: [Problem]
    let averageScore: Float
    let totalTimeSpent: TimeInterval
    let confidenceLevel: ConfidenceLevel
    let notes: [String]
}

struct ReviewPlanSummary {
    let plan: ReviewPlan
    let problem: Problem
    let isOverdue: Bool
    let daysUntilDue: Int
    let difficulty: DifficultyLevel
    let estimatedTime: TimeInterval
}

// MARK: - 统计相关结构

struct ProblemStatistics {
    let totalProblems: Int
    let averageMastery: Float
    let distributionByDifficulty: [DifficultyLevel: Int]
    let distributionByMastery: [MasteryLevel: Int]
    let mostCommonAlgorithms: [String]
    let mostCommonDataStructures: [String]
    let averageReviewsPerProblem: Float
    let streakCount: Int
}

struct ReviewStatistics {
    let totalReviews: Int
    let averageScore: Float
    let completionRate: Float
    let averageInterval: TimeInterval
    let currentStreak: Int
    let longestStreak: Int
    let reviewsThisWeek: Int
    let reviewsThisMonth: Int
}

struct LearningStatistics {
    let totalLearningTime: TimeInterval
    let sessionsCompleted: Int
    let averageSessionLength: TimeInterval
    let mostProductiveTime: DateComponents
    let improvementRate: Float
    let consistencyScore: Float
}

// MARK: - 窗口相关结构

struct WindowConfiguration {
    let type: ImprovedWindowManager.WindowType
    let title: String
    let size: CGSize
    let minimumSize: CGSize?
    let isResizable: Bool
    let styleMask: NSWindow.StyleMask
    let backingType: NSWindow.BackingStoreType
    let deferCreation: Bool
}

struct WindowState {
    let identifier: String
    let type: ImprovedWindowManager.WindowType
    let isVisible: Bool
    let isFocused: Bool
    let frame: NSRect
    let lastActivated: Date
    let data: Any?
}

// MARK: - 通知相关结构

struct NotificationContent {
    let id: String
    let title: String
    let body: String
    let category: String
    let userInfo: [String: Any]
    let sound: UNNotificationSound?
    let badge: Int?
}

// MARK: - 导入导出相关结构

struct ExportOptions {
    var includeProblems: Bool = true
    var includeNotes: Bool = true
    var includeReviewHistory: Bool = true
    var includeLearningPaths: Bool = true
    var format: ExportFormat = .json
    var dateRange: DateInterval? = nil
    var tags: [String] = []
}

enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case markdown = "markdown"
    
    var fileExtension: String {
        switch self {
        case .json: return ".json"
        case .csv: return ".csv"
        case .markdown: return ".md"
        }
    }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        }
    }
}

struct ImportResult {
    let success: Bool
    let importedProblems: Int
    let importedNotes: Int
    let importedLearningPaths: Int
    let errors: [String]
    let warnings: [String]
}

// MARK: - 用户偏好相关结构

struct UserPreferences {
    var defaultDifficulty: DifficultyLevel = .medium
    var preferredLanguage: String = "zh-CN"
    var dailyReviewGoal: Int = 10
    var reminderEnabled: Bool = true
    var reminderTime: DateComponents = DateComponents(hour: 9, minute: 0)
    var theme: Theme = .system
    var autoBackup: Bool = true
    var backupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    var searchHistoryLimit: Int = 100
    var analyticsEnabled: Bool = false
}

enum Theme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

// MARK: - 应用状态相关结构

struct AppStateSnapshot {
    let timestamp: Date
    let activeWindows: [WindowState]
    let currentProblem: Problem?
    let currentNote: Note?
    let searchQuery: String?
    let selectedFilters: SearchFilters?
    let userSessionDuration: TimeInterval
    let actionsPerformed: [String]
}

// MARK: - 网络相关结构

struct APIResponse<T: Codable> {
    let success: Bool
    let data: T?
    let error: String?
    let timestamp: Date
}

struct ProblemSyncInfo {
    let localId: UUID
    let remoteId: String?
    let lastSyncedAt: Date?
    let hasChanges: Bool
    let conflictDetected: Bool
}

// MARK: - 调试和诊断相关结构

struct DiagnosticReport {
    let generatedAt: Date
    let appVersion: String
    let buildNumber: String
    let systemVersion: String
    let deviceModel: String
    let crashReports: [CrashReport]
    let performanceMetrics: PerformanceMetrics
    let userFeedback: [UserFeedback]
    let recommendations: [String]
}

struct CrashReport {
    let timestamp: Date
    let reason: String
    let stackTrace: String
    let userAction: String?
    let appState: AppStateSnapshot?
}

struct PerformanceMetrics {
    let launchTime: TimeInterval
    let memoryUsage: UInt64
    let cpuUsage: Float
    let diskUsage: UInt64
    let networkLatency: TimeInterval?
    let databaseOperations: Int
    let averageResponseTime: TimeInterval
}

struct UserFeedback {
    let timestamp: Date
    let type: FeedbackType
    let content: String
    let rating: Int?
    let screenshot: Data?
    let context: String?
}

enum FeedbackType: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case improvement = "improvement"
    case question = "question"
    
    var displayName: String {
        switch self {
        case .bug: return "错误报告"
        case .feature: return "功能请求"
        case .improvement: return "改进建议"
        case .question: return "问题咨询"
        }
    }
}

// MARK: - 扩展和便利方法

extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

extension Array where Element == Problem {
    func filteredByDifficulty(_ difficulty: DifficultyLevel) -> [Problem] {
        return filter { $0.difficultyLevel == difficulty }
    }
    
    func filteredByMastery(_ mastery: MasteryLevel) -> [Problem] {
        return filter { $0.masteryLevel == mastery }
    }
    
    func sortedByMastery() -> [Problem] {
        return sorted { $0.mastery < $1.mastery }
    }
    
    func sortedByLastPractice() -> [Problem] {
        return sorted { 
            guard let date1 = $0.lastPracticeAt, let date2 = $1.lastPracticeAt else { 
                return $0.lastPracticeAt != nil
            }
            return date1 > date2
        }
    }
}

extension Array where Element == ReviewPlan {
    func dueReviews() -> [ReviewPlan] {
        return filter { $0.isDue }
    }
    
    func overdueReviews() -> [ReviewPlan] {
        return filter { $0.isOverdue }
    }
    
    func todayReviews() -> [ReviewPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return filter { review in
            guard let scheduledAt = review.scheduledAt else { return false }
            return scheduledAt >= today && scheduledAt < tomorrow
        }
    }
}

extension Dictionary where Key == String, Value == Int {
    func sortedByValue(descending: Bool = true) -> [(key: String, value: Int)] {
        return sorted { descending ? $0.value > $1.value : $0.value < $1.value }
    }
}

extension Float {
    func formattedAsPercentage() -> String {
        return String(format: "%.1f%%", self * 100)
    }
    
    func formattedAsDecimal() -> String {
        return String(format: "%.2f", self)
    }
}

extension TimeInterval {
    func formattedAsDuration() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d分钟", minutes)
        } else {
            return String(format: "%d秒", seconds)
        }
    }
}