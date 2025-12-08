import Foundation

/// App Store Connectで設定した製品IDを管理する設定
/// 実際の製品IDはApp Store Connectで設定した値と一致させる必要があります
enum PlanConfiguration {
    /// Standardプランの製品ID（App Store Connectで設定）
    static let standardPlanID = "standard_monthly"
    
    /// Proプランの製品ID（将来用）
    static let proPlanID = "pro_monthly"
    
    /// UserPlanから製品IDに変換
    static func productID(for plan: UserPlan) -> String? {
        switch plan {
        case .free:
            return nil // フリープランは購入不要
        case .standard:
            return standardPlanID
        case .pro:
            return proPlanID
        }
    }
    
    /// 製品IDからUserPlanに変換
    static func userPlan(from productID: String) -> UserPlan? {
        switch productID {
        case standardPlanID:
            return .standard
        case proPlanID:
            // Proプランは将来実装
            return nil
        default:
            return nil
        }
    }
}
