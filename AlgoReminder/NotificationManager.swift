import Foundation
import UserNotifications
import CoreData

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    // 通知更新节流机制
    private var lastUpdateTime: Date?
    private let updateThrottleInterval: TimeInterval = 2.0
    
    // 通知内容缓存
    private var cachedNotificationContent: [String: (title: String, body: String)] = [:]
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification authorization granted")
                self.scheduleDailyNotifications()
            } else {
                print("Notification authorization denied")
            }
        }
    }
    
    func scheduleDailyNotifications() {
        // Cancel existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule morning notification at 08:00
        scheduleNotification(
            identifier: "morning_review",
            title: "今日复习任务",
            body: "您有新的复习任务待完成，点击查看详情",
            hour: 8,
            minute: 0
        )
        
        // Schedule evening notification at 20:00
        scheduleNotification(
            identifier: "evening_review",
            title: "晚间复习提醒",
            body: "记得完成今日的复习任务，保持学习进度",
            hour: 20,
            minute: 0
        )
    }
    
    private func scheduleNotification(identifier: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "REVIEW_CATEGORY"
        content.userInfo = ["notification_type": identifier]
        
        // Configure trigger for daily notification
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Scheduled notification: \(identifier) at \(hour):\(minute)")
            }
        }
    }
    
    func scheduleImmediateNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "REVIEW_CATEGORY"
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling immediate notification: \(error)")
            }
        }
    }
    
    func updateNotificationContent() {
        let now = Date()
        
        // 节流机制：避免频繁更新通知
        if let lastUpdate = lastUpdateTime,
           now.timeIntervalSince(lastUpdate) < updateThrottleInterval {
            return
        }
        
        lastUpdateTime = now
        
        // Get today's review count
        let context = PersistenceController.shared.container.viewContext
        let todayReviews = ReviewScheduler.shared.getTodayReviews(context: context)
        
        let count = todayReviews.count
        let morningBody = count > 0 ? "您今天有 \(count) 个复习任务待完成" : "今天没有复习任务，继续保持！"
        let eveningBody = count > 0 ? "还有 \(count) 个复习任务待完成" : "今天已完成所有复习任务！"
        
        // 检查缓存，避免重复更新相同内容
        let morningContent = ("今日复习任务", morningBody)
        let eveningContent = ("晚间复习提醒", eveningBody)
        
        if cachedNotificationContent["morning_review"]?.0 != morningContent.0 || cachedNotificationContent["morning_review"]?.1 != morningContent.1 {
            updateNotificationContent(
                identifier: "morning_review",
                title: morningContent.0,
                body: morningContent.1
            )
            cachedNotificationContent["morning_review"] = morningContent
        }
        
        if cachedNotificationContent["evening_review"]?.0 != eveningContent.0 || cachedNotificationContent["evening_review"]?.1 != eveningContent.1 {
            updateNotificationContent(
                identifier: "evening_review",
                title: eveningContent.0,
                body: eveningContent.1
            )
            cachedNotificationContent["evening_review"] = eveningContent
        }
    }
    
    private func updateNotificationContent(identifier: String, title: String, body: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            if let request = requests.first(where: { $0.identifier == identifier }) {
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return }
                
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = UNNotificationSound.default
                content.categoryIdentifier = "REVIEW_CATEGORY"
                content.userInfo = request.content.userInfo
                
                let newRequest = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(newRequest) { error in
                    if let error = error {
                        print("Error updating notification: \(error)")
                    } else {
                        print("Successfully updated notification: \(identifier)")
                    }
                }
            }
        }
    }
    
    // 清理通知缓存
    func clearNotificationCache() {
        cachedNotificationContent.removeAll()
        lastUpdateTime = nil
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let notificationType = userInfo["notification_type"] as? String {
            handleNotificationAction(notificationType: notificationType)
        }
        
        completionHandler()
    }
    
    private func handleNotificationAction(notificationType: String) {
        DispatchQueue.main.async {
            switch notificationType {
            case "morning_review", "evening_review":
                // Show review dashboard through WindowManager
                WindowManager.shared.showReviewWindow()
            default:
                break
            }
        }
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_ACTION",
            title: "开始复习",
            options: [.foreground]
        )
        
        let skipAction = UNNotificationAction(
            identifier: "SKIP_ACTION",
            title: "结束",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "REVIEW_CATEGORY",
            actions: [reviewAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
