import Foundation
import CoreData
import os.log

// MARK: - Core Data 错误处理器
class CoreDataErrorHandler: ErrorHandler {
    private let logger = Logger(subsystem: "com.algorehearser.error", category: "CoreData")
    
    func handle(_ error: Error, context: String?) -> Bool {
        guard let coreDataError = error as? AlgoRehearserError else { return false }
        
        switch coreDataError {
        case .coreDataError(let error):
            switch error {
            case .saveFailed(let context, let underlyingError):
                return handleSaveFailed(context: context, underlyingError: underlyingError, additionalContext: context)
            case .fetchFailed(let entity, let underlyingError):
                return handleFetchFailed(entity: entity, underlyingError: underlyingError, context: context)
            case .migrationFailed(let underlyingError):
                return handleMigrationFailed(underlyingError: underlyingError, context: context)
            case .modelInconsistency(let description):
                return handleModelInconsistency(description: description, context: context)
            case .objectNotFound(let entity, let id):
                return handleObjectNotFound(entity: entity, id: id, context: context)
            case .contextInUse:
                return handleContextInUse(context: context)
            case .validationFailed(let description):
                return handleValidationFailed(description: description, context: context)
            case .constraintViolation(let description):
                return handleConstraintViolation(description: description, context: context)
            case .mergeConflict(let description):
                return handleMergeConflict(description: description, context: context)
            case .unknown(let description):
                return handleUnknownError(description: description, context: context)
            }
        default:
            return false
        }
    }
    
    func log(_ error: Error, context: String?) {
        logger.error("Core Data Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .coreDataError = algoError {
                return true
            }
        }
        
        // 检查是否是Core Data原生错误
        if let nsError = error as NSError? {
            return nsError.domain == "NSCocoaErrorDomain" || 
                   nsError.domain == "NSCoreDataError"
        }
        
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        guard let coreDataError = error as? AlgoRehearserError else { return nil }
        
        switch coreDataError {
        case .coreDataError(let error):
            switch error {
            case .saveFailed:
                return .retry
            case .migrationFailed:
                return .showUserAlertWithActions(
                    title: "数据迁移失败",
                    message: "应用数据迁移失败，可能需要重新安装应用。",
                    actions: [
                        AlertAction(title: "重新安装", style: .destructive) {
                            // 清除数据并重启
                            UnifiedErrorHandler.shared.clearDataAndRestart()
                        },
                        AlertAction(title: "稍后重试", style: .default) {}
                    ]
                )
            case .modelInconsistency:
                return .rollback
            default:
                return .showUserAlert(
                    title: "数据错误",
                    message: error.localizedDescription
                )
            }
        default:
            return nil
        }
    }
    
    // MARK: - 具体错误处理方法
    
    private func handleSaveFailed(context: String, underlyingError: Error?, additionalContext: String?) -> Bool {
        logger.error("Save failed in \(context): \(underlyingError?.localizedDescription ?? "Unknown error")")
        
        // 检查是否是并发冲突
        if let nsError = underlyingError as NSError?,
           nsError.code == NSManagedObjectMergeError {
            // 合并冲突，尝试解决
            return resolveMergeConflict(context: context)
        }
        
        // 其他保存错误，建议用户重试
        return false
    }
    
    private func handleFetchFailed(entity: String, underlyingError: Error?, context: String?) -> Bool {
        logger.warning("Fetch failed for entity \(entity): \(underlyingError?.localizedDescription ?? "Unknown error")")
        
        // 获取失败通常不是致命错误，可以继续
        return true
    }
    
    private func handleMigrationFailed(underlyingError: Error?, context: String?) -> Bool {
        logger.error("Migration failed: \(underlyingError?.localizedDescription ?? "Unknown error")")
        
        // 迁移失败是严重错误，需要用户干预
        return false
    }
    
    private func handleModelInconsistency(description: String, context: String?) -> Bool {
        logger.error("Model inconsistency: \(description)")
        
        // 模型不一致，可能需要重置数据库
        return false
    }
    
    private func handleObjectNotFound(entity: String, id: String, context: String?) -> Bool {
        logger.warning("Object not found: \(entity) with id \(id)")
        
        // 对象未找到，通常不是致命错误
        return true
    }
    
    private func handleContextInUse(context: String?) -> Bool {
        logger.warning("Context in use: \(context ?? "Unknown")")
        
        // 上下文正在使用，等待后重试
        Thread.sleep(forTimeInterval: 0.1)
        return true
    }
    
    private func resolveMergeConflict(context: String?) -> Bool {
        logger.info("Attempting to resolve merge conflict")
        
        // 合并冲突解决策略
        // 这里可以实现更复杂的冲突解决逻辑
        
        return false // 让上层处理
    }
    
    private func handleValidationFailed(description: String, context: String?) -> Bool {
        logger.warning("Validation failed: \(description)")
        
        // 显示错误提示，返回 false 表示需要上层处理
        return false
    }
    
    private func handleConstraintViolation(description: String, context: String?) -> Bool {
        logger.error("Constraint violation: \(description)")
        
        // 约束冲突是严重错误，返回 false 表示需要上层处理
        return false
    }
    
    private func handleMergeConflict(description: String, context: String?) -> Bool {
        logger.warning("Merge conflict: \(description)")
        
        // 合并冲突需要用户选择，返回 false 表示需要上层处理
        return false
    }
    
    private func handleUnknownError(description: String, context: String?) -> Bool {
        logger.error("Unknown Core Data error: \(description)")
        
        // 未知错误，返回 false 表示需要上层处理
        return false
    }
}

// MARK: - 验证错误处理器
class ValidationErrorHandler: ErrorHandler {
    private let logger = Logger(subsystem: "com.algorehearser.error", category: "Validation")
    
    func handle(_ error: Error, context: String?) -> Bool {
        guard let validationError = error as? AlgoRehearserError else { return false }
        
        switch validationError {
        case .validationError(let error):
            switch error {
            case .emptyField(let fieldName):
                return handleEmptyField(fieldName: fieldName, context: context)
            case .invalidFormat(let fieldName, let expected):
                return handleInvalidFormat(fieldName: fieldName, expected: expected, context: context)
            case .valueOutOfRange(let fieldName, _, _):
                return handleValueOutOfRange(fieldName: fieldName, context: context)
            case .duplicateValue(let fieldName):
                return handleDuplicateValue(fieldName: fieldName, context: context)
            case .missingRequiredField(let fieldName):
                return handleMissingRequiredField(fieldName: fieldName, context: context)
            }
        default:
            return false
        }
    }
    
    func log(_ error: Error, context: String?) {
        logger.warning("Validation Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .validationError = algoError {
                return true
            }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        guard let validationError = error as? AlgoRehearserError else { return nil }
        
        switch validationError {
        case .validationError(let error):
            switch error {
            case .emptyField, .missingRequiredField:
                return .showUserAlert(
                    title: "输入错误",
                    message: error.localizedDescription
                )
            case .invalidFormat:
                return .showUserAlert(
                    title: "格式错误",
                    message: error.localizedDescription
                )
            case .valueOutOfRange:
                return .showUserAlert(
                    title: "数值超出范围",
                    message: error.localizedDescription
                )
            case .duplicateValue:
                return .showUserAlert(
                    title: "重复值",
                    message: error.localizedDescription
                )
            }
        default:
            return nil
        }
    }
    
    // MARK: - 具体错误处理方法
    
    private func handleEmptyField(fieldName: String, context: String?) -> Bool {
        logger.info("Empty field validation failed: \(fieldName)")
        
        // 显示用户提示，通常需要用户干预
        return false
    }
    
    private func handleInvalidFormat(fieldName: String, expected: String, context: String?) -> Bool {
        logger.info("Invalid format validation failed: \(fieldName), expected: \(expected)")
        
        // 格式错误，需要用户修正
        return false
    }
    
    private func handleValueOutOfRange(fieldName: String, context: String?) -> Bool {
        logger.info("Value out of range validation failed: \(fieldName)")
        
        // 数值超出范围，需要用户修正
        return false
    }
    
    private func handleDuplicateValue(fieldName: String, context: String?) -> Bool {
        logger.info("Duplicate value validation failed: \(fieldName)")
        
        // 重复值，需要用户选择或修改
        return false
    }
    
    private func handleMissingRequiredField(fieldName: String, context: String?) -> Bool {
        logger.info("Missing required field validation failed: \(fieldName)")
        
        // 缺少必填字段，需要用户补充
        return false
    }
}

// MARK: - 复习错误处理器
class ReviewErrorHandler: ErrorHandler {
    private let logger = Logger(subsystem: "com.algorehearser.error", category: "Review")
    
    func handle(_ error: Error, context: String?) -> Bool {
        guard let reviewError = error as? AlgoRehearserError else { return false }
        
        switch reviewError {
        case .reviewError(let error):
            switch error {
            case .invalidScore(let score):
                return handleInvalidScore(score: score, context: context)
            case .reviewPlanNotFound(let id):
                return handleReviewPlanNotFound(id: id, context: context)
            case .schedulingFailed:
                return handleSchedulingFailed(context: context)
            case .intervalCalculationError:
                return handleIntervalCalculationError(context: context)
            case .duplicateReviewPlan:
                return handleDuplicateReviewPlan(context: context)
            }
        default:
            return false
        }
    }
    
    func log(_ error: Error, context: String?) {
        logger.warning("Review Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .reviewError = algoError {
                return true
            }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        guard let reviewError = error as? AlgoRehearserError else { return nil }
        
        switch reviewError {
        case .reviewError(let error):
            switch error {
            case .invalidScore:
                return .showUserAlert(
                    title: "无效分数",
                    message: "请输入0-5之间的分数"
                )
            case .reviewPlanNotFound:
                return .ignore // 忽略，可能只是临时的
            case .schedulingFailed:
                return .retry
            case .intervalCalculationError:
                return .retry
            case .duplicateReviewPlan:
                return .ignore
            }
        default:
            return nil
        }
    }
    
    // MARK: - 具体错误处理方法
    
    private func handleInvalidScore(score: Int, context: String?) -> Bool {
        logger.warning("Invalid score: \(score)")
        
        // 分数无效，需要用户重新输入
        return false
    }
    
    private func handleReviewPlanNotFound(id: String, context: String?) -> Bool {
        logger.warning("Review plan not found: \(id)")
        
        // 复习计划未找到，可能是缓存问题，可以忽略
        return true
    }
    
    private func handleSchedulingFailed(context: String?) -> Bool {
        logger.error("Review scheduling failed")
        
        // 调度失败，可以重试
        return false
    }
    
    private func handleIntervalCalculationError(context: String?) -> Bool {
        logger.error("Interval calculation error")
        
        // 间隔计算错误，使用默认间隔
        return true
    }
    
    private func handleDuplicateReviewPlan(context: String?) -> Bool {
        logger.warning("Duplicate review plan detected")
        
        // 重复的复习计划，忽略新创建的
        return true
    }
}

// MARK: - 未知错误处理器
class UnknownErrorHandler: ErrorHandler {
    private let logger = Logger(subsystem: "com.algorehearser.error", category: "Unknown")
    
    func handle(_ error: Error, context: String?) -> Bool {
        logger.error("Unknown error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
        
        // 对于未知错误，记录日志并显示通用错误提示
        return true
    }
    
    func log(_ error: Error, context: String?) {
        logger.error("Unknown error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        // 未知错误处理器可以处理任何错误
        return true
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        return .showUserAlert(
            title: "发生未知错误",
            message: "应用遇到了一个意外错误。请稍后重试，如果问题持续，请重启应用。"
        )
    }
}

// MARK: - 其他错误处理器的简化实现

class NetworkErrorHandler: ErrorHandler {
    func handle(_ error: Error, context: String?) -> Bool {
        Logger(subsystem: "com.algorehearser.error", category: "Network")
            .error("Network Error: \(error.localizedDescription)")
        return false
    }
    
    func log(_ error: Error, context: String?) {
        Logger(subsystem: "com.algorehearser.error", category: "Network")
            .error("Network Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .networkError = algoError { return true }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        return .retry
    }
}

class SearchErrorHandler: ErrorHandler {
    func handle(_ error: Error, context: String?) -> Bool {
        Logger(subsystem: "com.algorehearser.error", category: "Search")
            .error("Search Error: \(error.localizedDescription)")
        return true
    }
    
    func log(_ error: Error, context: String?) {
        Logger(subsystem: "com.algorehearser.error", category: "Search")
            .error("Search Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .searchError = algoError { return true }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        return .showUserAlert(
            title: "搜索错误",
            message: error.localizedDescription
        )
    }
}

class WindowErrorHandler: ErrorHandler {
    func handle(_ error: Error, context: String?) -> Bool {
        Logger(subsystem: "com.algorehearser.error", category: "Window")
            .error("Window Error: \(error.localizedDescription)")
        return true
    }
    
    func log(_ error: Error, context: String?) {
        Logger(subsystem: "com.algorehearser.error", category: "Window")
            .error("Window Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .windowError = algoError { return true }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        return .ignore
    }
}

class FileSystemErrorHandler: ErrorHandler {
    func handle(_ error: Error, context: String?) -> Bool {
        Logger(subsystem: "com.algorehearser.error", category: "FileSystem")
            .error("File System Error: \(error.localizedDescription)")
        return false
    }
    
    func log(_ error: Error, context: String?) {
        Logger(subsystem: "com.algorehearser.error", category: "FileSystem")
            .error("File System Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .fileSystemError = algoError { return true }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        return .showUserAlert(
            title: "文件系统错误",
            message: error.localizedDescription
        )
    }
}

class NotificationErrorHandler: ErrorHandler {
    func handle(_ error: Error, context: String?) -> Bool {
        Logger(subsystem: "com.algorehearser.error", category: "Notification")
            .error("Notification Error: \(error.localizedDescription)")
        return true
    }
    
    func log(_ error: Error, context: String?) {
        Logger(subsystem: "com.algorehearser.error", category: "Notification")
            .error("Notification Error: \(error.localizedDescription), Context: \(context ?? "Unknown")")
    }
    
    func canHandle(_ error: Error) -> Bool {
        if let algoError = error as? AlgoRehearserError {
            if case .notificationError = algoError { return true }
        }
        return false
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        return .showUserAlert(
            title: "通知错误",
            message: error.localizedDescription
        )
    }
}
