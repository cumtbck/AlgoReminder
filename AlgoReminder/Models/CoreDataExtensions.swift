import Foundation
import CoreData

// MARK: - Core Data实体扩展

extension Problem {
    // 便利的computed properties
    var masteryLevel: MasteryLevel {
        get { MasteryLevel(rawValue: mastery) ?? .notLearned }
        set { mastery = newValue.rawValue }
    }
    
    var difficultyLevel: DifficultyLevel {
        get { DifficultyLevel(rawValue: difficulty ?? "中等") ?? .medium }
        set { difficulty = newValue.rawValue }
    }
    
    var tagsArray: [String] {
        get {
            guard let tagsString = skillTags else { return [] }
            return tagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        set {
            skillTags = newValue.joined(separator: ", ")
        }
    }
    
    var companiesArray: [String] {
        get {
            guard let companiesString = companies else { return [] }
            return companiesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        set {
            companies = newValue.joined(separator: ", ")
        }
    }
    
    var skillTagsArray: [String] {
        get {
            guard let skillTagsString = skillTags else { return [] }
            return skillTagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        set {
            skillTags = newValue.joined(separator: ", ")
        }
    }
    
    // 计算属性
    var isOverdue: Bool {
        guard let lastPractice = lastPracticeAt else { return true }
        return lastPractice.addingTimeInterval(24 * 60 * 60) < Date()
    }
    
    var daysSinceLastPractice: Int {
        guard let lastPractice = lastPracticeAt else { return Int.max }
        return Calendar.current.dateComponents([.day], from: lastPractice, to: Date()).day ?? Int.max
    }
    
    var formattedDifficulty: String {
        return difficultyLevel.displayName
    }
    
    var formattedMastery: String {
        return masteryLevel.displayName
    }
    
    // 便利方法
    func addTag(_ tag: String) {
        var currentTags = tagsArray
        if !currentTags.contains(tag) {
            currentTags.append(tag)
            tagsArray = currentTags
        }
    }
    
    func removeTag(_ tag: String) {
        var currentTags = tagsArray
        if let index = currentTags.firstIndex(of: tag) {
            currentTags.remove(at: index)
            tagsArray = currentTags
        }
    }
    
    func updateMasteryBasedOnScore(_ score: Int) {
        let currentMastery = masteryLevel
        
        switch score {
        case 5:
            mastery = MasteryLevel.mastered.rawValue
        case 4:
            mastery = Int16(min(currentMastery.rawValue + 1, MasteryLevel.mastered.rawValue))
        case 3:
            // 保持现状
            break
        case 2:
            mastery = Int16(max(currentMastery.rawValue - 1, MasteryLevel.notLearned.rawValue))
        case 0, 1:
            mastery = Int16(max(currentMastery.rawValue - 2, MasteryLevel.notLearned.rawValue))
        default:
            break
        }
    }
}

extension ReviewPlan {
    // 便利的computed properties
    var reviewStatus: ReviewStatus {
        get { ReviewStatus(rawValue: status ?? "pending") ?? .pending }
        set { status = newValue.rawValue }
    }
    
    var intervalLevelEnum: ReviewIntervalLevel {
        get { ReviewIntervalLevel(rawValue: intervalLevel) ?? .first }
        set { intervalLevel = newValue.rawValue }
    }
    
    var confidenceLevel: ConfidenceLevel {
        get { ConfidenceLevel(rawValue: confidence) ?? .medium }
        set { confidence = newValue.rawValue }
    }
    
    // 计算属性
    var isDue: Bool {
        guard let scheduledDate = scheduledAt else { return false }
        return scheduledDate <= Date()
    }
    
    var isOverdue: Bool {
        guard let scheduledDate = scheduledAt else { return false }
        return scheduledDate < Calendar.current.startOfDay(for: Date())
    }
    
    var daysUntilDue: Int {
        guard let scheduledDate = scheduledAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: scheduledDate).day ?? 0
    }
    
    var formattedScheduledDate: String {
        guard let scheduledDate = scheduledAt else { return "未安排" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if isOverdue {
            return "逾期: \(formatter.string(from: scheduledDate))"
        } else if daysUntilDue == 0 {
            return "今天"
        } else if daysUntilDue == 1 {
            return "明天"
        } else {
            return formatter.string(from: scheduledDate)
        }
    }
    
    var intervalDisplayName: String {
        return intervalLevelEnum.displayName
    }
}

extension Note {
    // 便利的computed properties
    var noteTypeEnum: NoteType {
        get { NoteType(rawValue: noteType ?? "general") ?? .general }
        set { noteType = newValue.rawValue }
    }
    
    var tagsArray: [String] {
        get {
            guard let tagsString = tags else { return [] }
            return tagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }
    
    // 计算属性
    var calculatedWordCount: Int {
        return rawMarkdown?.split(separator: " ").count ?? 0
    }
    
    var hasContent: Bool {
        return !(rawMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
    
    var formattedNoteType: String {
        return noteTypeEnum.displayName
    }
    
    var noteTypeIcon: String {
        return noteTypeEnum.icon
    }
    
    // 便利方法
    func addTag(_ tag: String) {
        var currentTags = tagsArray
        if !currentTags.contains(tag) {
            currentTags.append(tag)
            tagsArray = currentTags
        }
    }
    
    func removeTag(_ tag: String) {
        var currentTags = tagsArray
        if let index = currentTags.firstIndex(of: tag) {
            currentTags.remove(at: index)
            tagsArray = currentTags
        }
    }
}

extension LearningPath {
    // 便利的computed properties
    var learningPathStatus: LearningPathStatus {
        get {
            if isArchived {
                return .archived
            } else if completedAt != nil {
                return .completed
            } else if !isActive {
                return .paused
            } else {
                return .active
            }
        }
        set {
            switch newValue {
            case .active:
                isActive = true
                isArchived = false
            case .completed:
                isActive = false
                isArchived = false
                completedAt = Date()
            case .paused:
                isActive = false
                isArchived = false
            case .archived:
                isActive = false
                isArchived = true
            }
        }
    }
    
    var difficultyLevel: DifficultyLevel {
        get { DifficultyLevel(rawValue: difficulty ?? "中等") ?? .medium }
        set { difficulty = newValue.rawValue }
    }
    
    var tagsArray: [String] {
        get {
            guard let tagsString = tags else { return [] }
            return tagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }
    
    // 计算属性
    var isActiveAndNotArchived: Bool {
        return isActive && !isArchived
    }
    
    var isCompleted: Bool {
        return completedAt != nil
    }
    
    var durationInDays: Int {
        guard let start = startedAt else { return 0 }
        let end = completedAt ?? Date()
        return Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    var formattedEstimatedDuration: String {
        return "\(estimatedDuration) 分钟"
    }
    
    var formattedDifficulty: String {
        return difficultyLevel.displayName
    }
    
    var formattedStatus: String {
        return learningPathStatus.displayName
    }
    
    // 便利方法
    func start() {
        if startedAt == nil {
            startedAt = Date()
            isActive = true
        }
    }
    
    func complete() {
        completedAt = Date()
        isActive = false
        progress = 1.0
    }
    
    func pause() {
        isActive = false
    }
    
    func resume() {
        if !isCompleted {
            isActive = true
        }
    }
    
    func archive() {
        isArchived = true
        isActive = false
    }
    
    func updateProgress() {
        guard totalProblems > 0 else {
            progress = 0.0
            return
        }
        
        progress = Float(completedProblems) / Float(totalProblems)
    }
    
    func addProblem(_ problem: Problem) {
        totalProblems += Int32(1)
        if problem.mastery >= MasteryLevel.proficient.rawValue {
            completedProblems += Int32(1)
        }
        updateProgress()
        updateMasteryProgress()
    }
    
    func removeProblem(_ problem: Problem) {
        totalProblems = max(Int32(0), totalProblems - Int32(1))
        if problem.mastery >= MasteryLevel.proficient.rawValue {
            completedProblems = max(Int32(0), completedProblems - Int32(1))
        }
        updateProgress()
        updateMasteryProgress()
    }
    
    func updateMasteryProgress() {
        guard let problemSet = problems as? Set<Problem>, !problemSet.isEmpty else {
            masteryProgress = 0.0
            return
        }
        
        let totalMastery = problemSet.reduce(into: Int32(0)) { $0 += Int32($1.mastery) }
        let maxPossibleMastery = Int32(problemSet.count) * Int32(MasteryLevel.mastered.rawValue)
        masteryProgress = maxPossibleMastery > 0 ? Float(totalMastery) / Float(maxPossibleMastery) : 0.0
    }
}