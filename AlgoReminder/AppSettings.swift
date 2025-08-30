import Foundation
import SwiftUI

// MARK: - 应用设置配置
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - 菜单栏图标设置
    @Published var menuBarIconName: String = "brain.head.profile"
    @Published var menuBarIconColor: Color = Color.primary
    @Published var showMenuBarBadge: Bool = true
    @Published var badgeColor: Color = Color.red
    
        
    // MARK: - 功能图标设置
    @Published var problemIconName: String = "doc.text"
    @Published var reviewIconName: String = "clock.arrow.circlepath"
    @Published var noteIconName: String = "note.text"
    @Published var settingsIconName: String = "gearshape"
    
    // MARK: - 其他设置
    @Published var showAnimations: Bool = true
    
    // MARK: - 主题设置
    @Published var themeMode: ThemeMode = .system
    @Published var accentColor: Color = .blue
    @Published var cardStyle: CardStyle = .modern
    
    enum ThemeMode: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "浅色"
            case .dark: return "深色"
            case .system: return "跟随系统"
            }
        }
    }
    
    enum CardStyle: String, CaseIterable {
        case modern = "modern"
        case classic = "classic"
        case compact = "compact"
        
        var displayName: String {
            switch self {
            case .modern: return "现代"
            case .classic: return "经典"
            case .compact: return "紧凑"
            }
        }
    }
    
    private init() {
        loadSettings()
    }
    
    // MARK: - 设置管理
    func loadSettings() {
        // 从 UserDefaults 加载设置
        if let iconName = UserDefaults.standard.string(forKey: "menuBarIconName") {
            menuBarIconName = iconName
        }
        
        if let badgeEnabled = UserDefaults.standard.object(forKey: "showMenuBarBadge") as? Bool {
            showMenuBarBadge = badgeEnabled
        }
        
        if let animationsEnabled = UserDefaults.standard.object(forKey: "showAnimations") as? Bool {
            showAnimations = animationsEnabled
        }
        
                
        // 加载功能图标设置
        if let problemIcon = UserDefaults.standard.string(forKey: "problemIconName") {
            problemIconName = problemIcon
        }
        
        if let reviewIcon = UserDefaults.standard.string(forKey: "reviewIconName") {
            reviewIconName = reviewIcon
        }
        
        if let noteIcon = UserDefaults.standard.string(forKey: "noteIconName") {
            noteIconName = noteIcon
        }
        
        if let settingsIcon = UserDefaults.standard.string(forKey: "settingsIconName") {
            settingsIconName = settingsIcon
        }
        
        // 加载颜色设置
        menuBarIconColor = UserDefaults.standard.loadColor(forKey: "menuBarIconColor")
        badgeColor = UserDefaults.standard.loadColor(forKey: "badgeColor")
        
        // 加载主题设置
        if let themeModeRaw = UserDefaults.standard.string(forKey: "themeMode"),
           let themeMode = ThemeMode(rawValue: themeModeRaw) {
            self.themeMode = themeMode
        }
        
        accentColor = UserDefaults.standard.loadColor(forKey: "accentColor")
        
        if let cardStyleRaw = UserDefaults.standard.string(forKey: "cardStyle"),
           let cardStyle = CardStyle(rawValue: cardStyleRaw) {
            self.cardStyle = cardStyle
        }
    }
    
    func saveSettings() {
        // 保存设置到 UserDefaults
        UserDefaults.standard.set(menuBarIconName, forKey: "menuBarIconName")
        UserDefaults.standard.set(showMenuBarBadge, forKey: "showMenuBarBadge")
        UserDefaults.standard.set(showAnimations, forKey: "showAnimations")
        
        // 保存功能图标设置
        UserDefaults.standard.set(problemIconName, forKey: "problemIconName")
        UserDefaults.standard.set(reviewIconName, forKey: "reviewIconName")
        UserDefaults.standard.set(noteIconName, forKey: "noteIconName")
        UserDefaults.standard.set(settingsIconName, forKey: "settingsIconName")
        
        // 保存颜色设置
        UserDefaults.standard.saveColor(menuBarIconColor, forKey: "menuBarIconColor")
        UserDefaults.standard.saveColor(badgeColor, forKey: "badgeColor")
        
        // 保存主题设置
        UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        UserDefaults.standard.saveColor(accentColor, forKey: "accentColor")
        UserDefaults.standard.set(cardStyle.rawValue, forKey: "cardStyle")
        
        // 通知其他组件设置已更改
        NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
        NotificationCenter.default.post(name: .menuBarIconChanged, object: nil)
    }
    
    // MARK: - 重置设置
    func resetToDefaults() {
        menuBarIconName = "brain.head.profile"
        menuBarIconColor = Color.primary
        showMenuBarBadge = true
        badgeColor = Color.red
        problemIconName = "doc.text"
        reviewIconName = "clock.arrow.circlepath"
        noteIconName = "note.text"
        settingsIconName = "gearshape"
        showAnimations = true
        themeMode = .system
        accentColor = .blue
        cardStyle = .modern
        
        saveSettings()
    }
}


// MARK: - UserDefaults 扩展
extension UserDefaults {
    func saveColor(_ color: Color, forKey key: String) {
        let nsColor = NSColor(color)
        let data = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
        set(data, forKey: key)
    }
    
    func loadColor(forKey key: String) -> Color {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return Color.primary
        }
        return Color(nsColor)
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let appSettingsChanged = Notification.Name("appSettingsChanged")
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
}