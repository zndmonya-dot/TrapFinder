import Foundation
import Combine
import SwiftUI

// ユーザーのプラン定義
// ※基本無料・広告収入のみの仕様のため、現在はfreeのみ使用
enum UserPlan: String, CaseIterable {
    case free
    
    // 使用するAIモデル
    var aiModel: String {
        return "gpt-4o-mini"
    }
    
    // 1日の回数制限（-1は無制限）
    var dailyLimit: Int {
        return -1  // 動画広告視聴で無制限
    }
    
    // 1回の文字数制限
    var characterLimit: Int {
        return 50_000
    }
}

/// プラン管理サービス
/// ※本アプリは基本無料で、マネタイズは広告収入のみです（サブスクリプション機能は使用していません）
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    // 基本無料・広告収入のみの仕様：全ユーザーがFreeプラン（広告あり・無制限）として扱う
    @Published var currentPlan: UserPlan = .free
    
    // 基本無料・広告収入のみの仕様のため、常にfalse
    var isPro: Bool {
        return false
    }
    
    private init() {
        // 基本無料・広告収入のみの仕様のため、サブスクリプション関連の初期化処理は不要
    }
}
