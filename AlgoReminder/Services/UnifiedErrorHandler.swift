import Foundation
import CoreData
import os.log
import AppKit

// MARK: - 错误类型枚举
enum AlgoRehearserError: Error, LocalizedError {
    case coreDataError(CoreDataError)
    case networkError(NetworkError)
    case searchError(SearchError)
    case reviewError(ReviewError)
    case windowError(WindowError)
    case validationError(ValidationError)
    case fileSystemError(FileSystemError)
    case notificationError(NotificationError)
    case unknownError(description: String)
    
    // MARK: - 核心数据错误
    enum CoreDataError {
        case saveFailed(context: String, underlyingError: Error?)
        case fetchFailed(entity: String, underlyingError: Error?)
        case migrationFailed(underlyingError: Error?)
        case modelInconsistency(description: String)
        case objectNotFound(entity: String, id: String)
        case contextInUse
        case validationFailed(description: String)
        case constraintViolation(description: String)
        case mergeConflict(description: String)
        case unknown(description: String)
    }
    
    // MARK: - 网络错误
    enum NetworkError {
        case requestFailed(url: String, statusCode: Int?)
        case timeout
        case noInternetConnection
        case invalidURL
        case responseParsingFailed
    }
    
    // MARK: - 搜索错误
    enum SearchError {
        case queryTooShort(minLength: Int)
        case invalidFilters
        case embeddingModelFailed
        case noResultsFound
        case indexNotAvailable
    }
    
    // MARK: - 复习错误
    enum ReviewError {
        case invalidScore(score: Int)
        case reviewPlanNotFound(id: String)
        case schedulingFailed
        case intervalCalculationError
        case duplicateReviewPlan
    }
    
    // MARK: - 窗口错误
    enum WindowError {
        case windowCreationFailed(type: String)
        case windowNotFound(identifier: String)
        case windowAlreadyOpen(type: String)
        case invalidWindowState
    }
    
    // MARK: - 验证错误
    enum ValidationError {
        case emptyField(fieldName: String)
        case invalidFormat(fieldName: String, expected: String)
        case valueOutOfRange(fieldName: String, min: Any, max: Any)
        case duplicateValue(fieldName: String)
        case missingRequiredField(fieldName: String)
    }
    
    // MARK: - 文件系统错误
    enum FileSystemError {
        case fileNotFound(path: String)
        case permissionDenied(path: String)
        case diskFull
        case invalidFileType
        case fileCorrupted(path: String)
        case exportFailed(path: String)
    }
    
    // MARK: - 通知错误
    enum NotificationError {
        case permissionDenied
        case schedulingFailed
        case invalidNotificationContent
        case notificationNotDelivered
    }
    
    // MARK: - LocalizedError 实现
    var errorDescription: String? {
        switch self {
        case .coreDataError(let error):
            return "数据错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .searchError(let error):
            return "搜索错误: \(error.localizedDescription)"
        case .reviewError(let error):
            return "复习错误: \(error.localizedDescription)"
        case .windowError(let error):
            return "窗口错误: \(error.localizedDescription)"
        case .validationError(let error):
            return "验证错误: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "文件系统错误: \(error.localizedDescription)"
        case .notificationError(let error):
            return "通知错误: \(error.localizedDescription)"
        case .unknownError(let description):
            return "未知错误: \(description)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .coreDataError(.saveFailed(let context, _)):
            return "无法保存数据到 \(context)"
        case .coreDataError(.fetchFailed(let entity, _)):
            return "无法获取 \(entity) 数据"
        case .validationError(.emptyField(let fieldName)):
            return "\(fieldName) 不能为空"
        case .reviewError(.invalidScore(let score)):
            return "无效的分数: \(score)"
        case .networkError(.noInternetConnection):
            return "网络连接不可用"
        default:
            return errorDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .coreDataError(.saveFailed(_, _)):
            return "请检查网络连接，稍后重试。如果问题持续，请重新启动应用。"
        case .coreDataError(.migrationFailed(_)):
            return "数据迁移失败。请尝试删除应用后重新安装。"
        case .validationError(.emptyField(let fieldName)):
            return "请填写 \(fieldName) 字段。"
        case .reviewError(.invalidScore(_)):
            return "请输入0-5之间的分数。"
        case .networkError(.noInternetConnection):
            return "请检查网络连接后重试。"
        case .fileSystemError(.permissionDenied(let path)):
            return "请检查对 \(path) 的访问权限。"
        case .notificationError(.permissionDenied):
            return "请在系统设置中允许应用发送通知。"
        default:
            return "请稍后重试。如果问题持续，请联系技术支持。"
        }
    }
}

// MARK: - 错误枚举的LocalizedError扩展

extension AlgoRehearserError.CoreDataError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .saveFailed(let context, _):
            return "保存失败: \(context)"
        case .fetchFailed(let entity, _):
            return "获取失败: \(entity)"
        case .migrationFailed(_):
            return "数据迁移失败"
        case .modelInconsistency(let description):
            return "模型不一致: \(description)"
        case .objectNotFound(let entity, let id):
            return "对象未找到: \(entity) (ID: \(id))"
        case .contextInUse:
            return "数据上下文正在使用"
        case .validationFailed(let description):
            return "验证失败: \(description)"
        case .constraintViolation(let description):
            return "约束冲突: \(description)"
        case .mergeConflict(let description):
            return "合并冲突: \(description)"
        case .unknown(let description):
            return "未知错误: \(description)"
        }
    }
}

extension AlgoRehearserError.NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .requestFailed(let url, let statusCode):
            return "请求失败: \(url) (状态码: \(statusCode ?? 0))"
        case .timeout:
            return "请求超时"
        case .noInternetConnection:
            return "无网络连接"
        case .invalidURL:
            return "无效的URL"
        case .responseParsingFailed:
            return "响应解析失败"
        }
    }
}

extension AlgoRehearserError.SearchError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .queryTooShort(let minLength):
            return "查询过短，至少需要 \(minLength) 个字符"
        case .invalidFilters:
            return "无效的搜索过滤器"
        case .embeddingModelFailed:
            return "嵌入模型加载失败"
        case .noResultsFound:
            return "未找到搜索结果"
        case .indexNotAvailable:
            return "搜索索引不可用"
        }
    }
}

extension AlgoRehearserError.ReviewError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidScore(let score):
            return "无效的分数: \(score)"
        case .reviewPlanNotFound(let id):
            return "复习计划未找到: \(id)"
        case .schedulingFailed:
            return "复习调度失败"
        case .intervalCalculationError:
            return "间隔计算错误"
        case .duplicateReviewPlan:
            return "重复的复习计划"
        }
    }
}

extension AlgoRehearserError.WindowError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .windowCreationFailed(let type):
            return "窗口创建失败: \(type)"
        case .windowNotFound(let identifier):
            return "窗口未找到: \(identifier)"
        case .windowAlreadyOpen(let type):
            return "窗口已打开: \(type)"
        case .invalidWindowState:
            return "无效的窗口状态"
        }
    }
}

extension AlgoRehearserError.ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyField(let fieldName):
            return "字段为空: \(fieldName)"
        case .invalidFormat(let fieldName, let expected):
            return "格式无效: \(fieldName) (期望: \(expected))"
        case .valueOutOfRange(let fieldName, _, _):
            return "值超出范围: \(fieldName)"
        case .duplicateValue(let fieldName):
            return "重复的值: \(fieldName)"
        case .missingRequiredField(let fieldName):
            return "缺少必需字段: \(fieldName)"
        }
    }
}

extension AlgoRehearserError.FileSystemError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "文件未找到: \(path)"
        case .permissionDenied(let path):
            return "权限被拒绝: \(path)"
        case .diskFull:
            return "磁盘空间不足"
        case .invalidFileType:
            return "无效的文件类型"
        case .fileCorrupted(let path):
            return "文件损坏: \(path)"
        case .exportFailed(let path):
            return "导出失败: \(path)"
        }
    }
}

extension AlgoRehearserError.NotificationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "通知权限被拒绝"
        case .schedulingFailed:
            return "通知调度失败"
        case .invalidNotificationContent:
            return "无效的通知内容"
        case .notificationNotDelivered:
            return "通知未送达"
        }
    }
}

// MARK: - 错误处理器协议
protocol ErrorHandler {
    func handle(_ error: Error, context: String?) -> Bool
    func log(_ error: Error, context: String?)
    func canHandle(_ error: Error) -> Bool
    func recoveryAction(for error: Error) -> RecoveryAction?
}

// MARK: - 恢复动作枚举
enum RecoveryAction {
    case retry
    case ignore
    case rollback
    case showUserAlert(title: String, message: String)
    case showUserAlertWithActions(title: String, message: String, actions: [AlertAction])
    case restartApp
    case clearDataAndRestart
    case custom(action: () -> Void)
}

struct AlertAction {
    let title: String
    let style: AlertStyle
    let handler: () -> Void
}

enum AlertStyle {
    case `default`
    case destructive
    case critical
    case informative
}

// MARK: - 统一错误处理器
class UnifiedErrorHandler: ObservableObject, ErrorHandler {
    static let shared = UnifiedErrorHandler()
    
    private let logger = Logger(subsystem: "com.algorehearser.error", category: "ErrorHandler")
    private var handlers: [ErrorHandler] = []
    
    @Published var lastError: Error?
    @Published var errorCount: Int = 0
    
    private init() {
        setupHandlers()
    }
    
    // MARK: - 处理器设置
    
    private func setupHandlers() {
        handlers = [
            CoreDataErrorHandler(),
            NetworkErrorHandler(),
            SearchErrorHandler(),
            ReviewErrorHandler(),
            WindowErrorHandler(),
            ValidationErrorHandler(),
            FileSystemErrorHandler(),
            NotificationErrorHandler(),
            UnknownErrorHandler()
        ]
    }
    
    // MARK: - 公共接口
    
    func handle(_ error: Error, context: String? = nil) -> Bool {
        errorCount += 1
        lastError = error
        
        // 记录错误
        log(error, context: context)
        
        // 查找合适的处理器
        for handler in handlers {
            if handler.canHandle(error) {
                let handled = handler.handle(error, context: context)
                
                // 如果处理器返回false，继续尝试其他处理器
                if handled {
                    return true
                }
            }
        }
        
        // 没有处理器能处理，使用默认处理
        return handleUnknownError(error, context: context)
    }
    
    func log(_ error: Error, context: String? = nil) {
        let contextInfo = context ?? "Unknown"
        
        // 根据错误类型选择日志级别
        switch error {
        case AlgoRehearserError.coreDataError:
            logger.error("Core Data Error in \(contextInfo): \(error.localizedDescription)")
        case AlgoRehearserError.validationError:
            logger.warning("Validation Error in \(contextInfo): \(error.localizedDescription)")
        case AlgoRehearserError.networkError:
            logger.info("Network Error in \(contextInfo): \(error.localizedDescription)")
        default:
            logger.error("Unhandled Error in \(contextInfo): \(error.localizedDescription)")
        }
        
        // 输出详细错误信息
        if let nsError = error as NSError? {
            logger.debug("Error details: \(nsError.userInfo)")
        }
    }
    
    func canHandle(_ error: Error) -> Bool {
        return handlers.contains { $0.canHandle(error) }
    }
    
    func recoveryAction(for error: Error) -> RecoveryAction? {
        for handler in handlers {
            if handler.canHandle(error) {
                return handler.recoveryAction(for: error)
            }
        }
        return .showUserAlert(
            title: "发生错误",
            message: error.localizedDescription
        )
    }
    
    // MARK: - 错误包装
    
    func wrapCoreDataError(_ error: Error, context: String) -> AlgoRehearserError {
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSValidationMultipleErrorsError:
                return .coreDataError(.validationFailed(description: error.localizedDescription))
            case NSManagedObjectConstraintValidationError:
                return .coreDataError(.constraintViolation(description: error.localizedDescription))
            case NSManagedObjectMergeError:
                return .coreDataError(.mergeConflict(description: error.localizedDescription))
            default:
                return .coreDataError(.saveFailed(context: context, underlyingError: error))
            }
        }
        return .coreDataError(.unknown(description: error.localizedDescription))
    }
    
    func wrapValidationError(_ fieldName: String, error: Error) -> AlgoRehearserError {
        return .validationError(.invalidFormat(fieldName: fieldName, expected: error.localizedDescription))
    }
    
    // MARK: - 统计和监控
    
    func getErrorStatistics() -> ErrorStatistics {
        // 这里可以实现错误统计逻辑
        return ErrorStatistics(
            totalErrors: errorCount,
            errorsByType: [:],
            recentErrors: []
        )
    }
    
    func resetErrorCount() {
        errorCount = 0
        lastError = nil
    }
    
    // MARK: - 私有方法
    
    private func handleUnknownError(_ error: Error, context: String?) -> Bool {
        logger.error("Unknown error in \(context ?? "Unknown"): \(error.localizedDescription)")
        
        // 对于未知错误，显示用户提示
        let recoveryAction = RecoveryAction.showUserAlert(
            title: "发生未知错误",
            message: "应用遇到了一个意外错误。请稍后重试，如果问题持续，请重启应用。"
        )
        
        executeRecoveryAction(recoveryAction)
        return true
    }
    
    private func executeRecoveryAction(_ action: RecoveryAction) {
        DispatchQueue.main.async {
            switch action {
            case .retry:
                // 重试逻辑由调用者实现
                break
            case .ignore:
                // 忽略错误
                break
            case .rollback:
                // 回滚逻辑由调用者实现
                break
            case .showUserAlert(let title, let message):
                self.showAlert(title: title, message: message)
            case .showUserAlertWithActions(let title, let message, let actions):
                self.showAlertWithActions(title: title, message: message, actions: actions)
            case .restartApp:
                self.restartApp()
            case .clearDataAndRestart:
                self.clearDataAndRestart()
            case .custom(let action):
                action()
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        // 在macOS上显示alert
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    private func showAlertWithActions(title: String, message: String, actions: [AlertAction]) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        
        for action in actions {
            alert.addButton(withTitle: action.title)
        }
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let action = actions.first {
            action.handler()
        }
    }
    
    private func restartApp() {
        let workspace = NSWorkspace.shared
        let url = Bundle.main.bundleURL
        workspace.launchApplication(
            withBundleIdentifier: Bundle.main.bundleIdentifier!,
            options: [.async],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
        NSApplication.shared.terminate(nil)
    }
    
    func clearDataAndRestart() {
        let alert = NSAlert()
        alert.messageText = "确认清除数据"
        alert.informativeText = "这将清除所有学习数据，此操作不可撤销。确定要继续吗？"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "清除并重启")
        
        let response = alert.runModal()
        if response == NSApplication.ModalResponse.alertSecondButtonReturn {
            // 清除数据逻辑
            PersistenceController.shared.clearAllData()
            restartApp()
        }
    }
}

// MARK: - 错误统计结构
struct ErrorStatistics {
    let totalErrors: Int
    let errorsByType: [String: Int]
    let recentErrors: [Error]
}

// MARK: - 便利方法扩展

extension UnifiedErrorHandler {
    
    func safeExecute<T>(
        _ operation: () throws -> T,
        context: String,
        fallback: T? = nil,
        retryCount: Int = 1
    ) -> T? {
        var lastError: Error?
        
        for attempt in 0...retryCount {
            do {
                let result = try operation()
                if attempt > 0 {
                    logger.info("Operation succeeded after \(attempt) retries")
                }
                return result
            } catch {
                lastError = error
                logger.warning("Operation failed (attempt \(attempt + 1)): \(error.localizedDescription)")
                
                if attempt < retryCount {
                    // 等待一段时间后重试
                    Thread.sleep(forTimeInterval: TimeInterval(attempt + 1) * 0.5)
                }
            }
        }
        
        // 所有重试都失败
        if let error = lastError {
            handle(error, context: context)
        }
        
        return fallback
    }
    
    func safeExecuteAsync<T>(
        _ operation: @escaping () throws -> T,
        context: String,
        completion: @escaping (Result<T, Error>) -> Void,
        retryCount: Int = 1
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var lastError: Error?
            
            for attempt in 0...retryCount {
                do {
                    let result = try operation()
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                    return
                } catch {
                    lastError = error
                    self.logger.warning("Async operation failed (attempt \(attempt + 1)): \(error.localizedDescription)")
                    
                    if attempt < retryCount {
                        // 等待一段时间后重试
                        Thread.sleep(forTimeInterval: TimeInterval(attempt + 1) * 0.5)
                    }
                }
            }
            
            // 所有重试都失败
            if let error = lastError {
                DispatchQueue.main.async {
                    self.handle(error, context: context)
                    completion(.failure(error))
                }
            }
        }
    }
}