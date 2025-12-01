import Foundation
import Combine
import SwiftUI

// ユーザーのプラン定義
enum UserPlan: String, CaseIterable {
    case free
    case standard
    
    var name: String {
        switch self {
        case .free: return L10n.freePlan.text
        case .standard: return L10n.standardPlan.text
        }
    }
    
    // 使用するAIモデル（デフォルト値）
    var aiModel: String {
        switch self {
        case .free, .standard: return "gpt-4o-mini"
        }
    }
    
    // 1日の回数制限（-1は無制限）
    var dailyLimit: Int {
        switch self {
        case .free: return 3
        case .standard: return -1
        }
    }
    
    // 1回の文字数制限
    var characterLimit: Int {
        return 100000 // 100,000文字に緩和（約50ページ分）
    }
}

class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()
    
    @Published var currentPlan: UserPlan = .free
    @Published var scanCountToday = 0
    
    // 古いフラグとの互換性（StandardならTrue）
    var isPro: Bool {
        return currentPlan == .standard
    }
    
    private let userDefaults = UserDefaults.standard
    private let scanCountKey = "scanCount"
    private let lastScanDateKey = "lastScanDate"
    private let userPlanKey = "userPlan" // デモ用：プラン保存キー
    
    private init() {
        // デモ用：保存されたプランを読み込む
        if let savedPlan = userDefaults.string(forKey: userPlanKey),
           let plan = UserPlan(rawValue: savedPlan) {
            self.currentPlan = plan
        }
        checkDailyLimit()
    }
    
    func checkDailyLimit() {
        let lastDate = userDefaults.object(forKey: lastScanDateKey) as? Date ?? Date.distantPast
        
        if !Calendar.current.isDateInToday(lastDate) {
            scanCountToday = 0
            userDefaults.set(0, forKey: scanCountKey)
            userDefaults.set(Date(), forKey: lastScanDateKey)
        } else {
            scanCountToday = userDefaults.integer(forKey: scanCountKey)
        }
    }
    
    func incrementScanCount() {
        // 無制限プランでない場合のみカウント
        if currentPlan.dailyLimit != -1 {
            scanCountToday += 1
            userDefaults.set(scanCountToday, forKey: scanCountKey)
            userDefaults.set(Date(), forKey: lastScanDateKey)
        }
    }
    
    var canScan: Bool {
        if currentPlan.dailyLimit == -1 { return true }
        return scanCountToday < currentPlan.dailyLimit
    }
    
    var remainingFreeScans: Int {
        if currentPlan.dailyLimit == -1 { return 999 }
        return max(0, currentPlan.dailyLimit - scanCountToday)
    }
    
    // 課金処理（シミュレーション）
    // 引数でプランを指定できるように変更
    func purchase(plan: UserPlan, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.currentPlan = plan
            self.userDefaults.set(plan.rawValue, forKey: self.userPlanKey) // デモ用保存
            completion(true)
        }
    }
    
    // 旧メソッド（互換性のため残すが、Standardへのアップグレードとする）
    func purchasePro(completion: @escaping (Bool) -> Void) {
        purchase(plan: .standard, completion: completion)
    }
    
    func restorePurchases(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 本来はRevenueCatから情報を取得してプランを決定する
            self.currentPlan = .standard
            self.userDefaults.set(UserPlan.standard.rawValue, forKey: self.userPlanKey)
            completion(true)
        }
    }
}
