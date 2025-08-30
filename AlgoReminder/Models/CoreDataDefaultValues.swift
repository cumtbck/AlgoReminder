import Foundation
import CoreData

// MARK: - 为 CoreData 实体添加默认值支持

extension Problem {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // 如果创建日期为空，设置为当前时间
        if createdAt == nil {
            createdAt = Date()
        }
        
        // 如果更新日期为空，设置为当前时间
        if updatedAt == nil {
            updatedAt = Date()
        }
    }
}

extension ReviewPlan {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // 如果调度日期为空，设置为当前时间
        if scheduledAt == nil {
            scheduledAt = Date()
        }
    }
}

extension Note {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // 如果创建日期为空，设置为当前时间
        if createdAt == nil {
            createdAt = Date()
        }
        
        // 如果更新日期为空，设置为当前时间
        if updatedAt == nil {
            updatedAt = Date()
        }
    }
}

extension LearningPath {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // 如果创建日期为空，设置为当前时间
        if createdAt == nil {
            createdAt = Date()
        }
    }
}
