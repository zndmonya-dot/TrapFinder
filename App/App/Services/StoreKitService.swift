import Foundation
import Combine
import SwiftUI
import StoreKit

// ユーザーのプラン定義
enum UserPlan: String, CaseIterable {
    case free
    case standard
    case pro
    
    var name: String {
        switch self {
        case .free: return L10n.freePlan.text
        case .standard: return L10n.standardPlan.text
        case .pro: return L10n.proPlan.text
        }
    }
    
    // 使用するAIモデル
    var aiModel: String {
        switch self {
        case .free, .standard: return "gpt-4o-mini"
        case .pro: return "gpt-4o"  // プロプランは高性能AIモデル
        }
    }
    
    // 1日の回数制限（-1は無制限）
    // フリープランは動画広告を視聴するたびに解析可能なため、無制限
    var dailyLimit: Int {
        switch self {
        case .free: return -1  // 動画広告視聴で無制限
        case .standard: return -1
        case .pro: return 10  // プロプランは1日10回まで
        }
    }
    
    // 1回の文字数制限
    // GPT-4o-mini/GPT-4oのmax_tokens上限（16384）に合わせて調整
    // 計算: 入力テキスト + プロンプト + 出力(max_tokens) = 128K以内
    // 安全マージンを考慮し、入力テキストは約20,000トークン（約50,000文字）までに制限
    // 文字数上限を超えるとAPI上限（max_tokens 16,384）にかかりやすいため抑制
    var characterLimit: Int {
        switch self {
        case .free:
            return 10_000
        case .standard, .pro:
            return 50_000  // 100,000から50,000に変更（max_tokens上限に合わせて）
        }
    }
}

/// StoreKit 2を使用した購読管理サービス
class StoreKitService: NSObject, ObservableObject {
    static let shared = StoreKitService()
    
    @Published var currentPlan: UserPlan = .free
    @Published var scanCountToday = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var availableProducts: [Product] = []
    
    // 古いフラグとの互換性（StandardならTrue）
    var isPro: Bool {
        return currentPlan == .standard
    }
    
    private let userDefaults = UserDefaults.standard
    private let scanCountKey = "scanCount"
    private let lastScanDateKey = "lastScanDate"
    
    // 製品ID（App Store Connectで設定する必要がある）
    private let productIDs = ["standard_monthly", "pro_monthly"]
    
    // トランザクション更新の監視タスク
    private var updateListenerTask: Task<Void, Error>?
    
    private override init() {
        super.init()
        checkDailyLimit()
        
        // トランザクション更新を監視
        updateListenerTask = listenForTransactions()
        
        #if DEBUG
        // デバッグモードでは強制的にスタンダードプランに設定（テスト用）
        currentPlan = .standard
        #endif
        
        // 初期状態を取得
        Task {
            await updateSubscriptionStatus()
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    /// トランザクション更新を監視
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            var consecutiveErrors = 0
            let maxConsecutiveErrors = 5
            
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                    consecutiveErrors = 0 // 成功したらエラーカウントをリセット
                } catch {
                    consecutiveErrors += 1
                    #if DEBUG
                    print("Transaction verification failed (\(consecutiveErrors)/\(maxConsecutiveErrors)): \(error)")
                    #endif
                    
                    // 連続エラーが多すぎる場合は、エラーメッセージを表示
                    if consecutiveErrors >= maxConsecutiveErrors {
                        await MainActor.run {
                            self.errorMessage = L10n.purchaseErrorGeneric.text
                        }
                        // エラーカウントをリセット（ユーザーに通知した後）
                        consecutiveErrors = 0
                    }
                    
                    // エラー時は少し待機してから続行（レート制限対策）
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                }
            }
        }
    }
    
    /// トランザクションの検証（nonisolated static）
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    /// 製品情報を読み込む
    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: productIDs)
            self.availableProducts = products
            
            #if DEBUG
            if products.isEmpty {
                print("⚠️ [StoreKitService] 製品が見つかりませんでした。")
                print("   App Store Connectで以下の製品IDを設定してください:")
                print("   - standard_monthly")
            } else {
                print("✅ [StoreKitService] \(products.count)個の製品を読み込みました")
                for product in products {
                    print("   - \(product.id): \(product.displayName) - \(product.displayPrice)")
                }
            }
            #endif
        } catch {
            #if DEBUG
            self.errorMessage = String(format: L10n.productLoadErrorDebug.text, error.localizedDescription)
            #else
            self.errorMessage = String(format: L10n.productLoadError.text, error.localizedDescription)
            #endif
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
        }
    }
    
    /// 購読状態を更新
    @MainActor
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        // 現在の購読状態を確認
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                
                // 製品IDを確認
                if productIDs.contains(transaction.productID) {
                    hasActiveSubscription = true
                    break
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        
        // プランを更新
        await MainActor.run {
            currentPlan = hasActiveSubscription ? .standard : .free
        }
    }
    
    func checkDailyLimit() {
        let lastDate = userDefaults.object(forKey: lastScanDateKey) as? Date ?? Date.distantPast
        
        // ユーザーのローカルタイムゾーンで日付を比較
        let calendar = Calendar.current
        let now = Date()
        
        // 今日の開始時刻（ローカルタイムゾーン）
        let startOfToday = calendar.startOfDay(for: now)
        
        // 最後にスキャンした日付の開始時刻（ローカルタイムゾーン）
        let startOfLastDate = calendar.startOfDay(for: lastDate)
        
        // 日付が変わったかチェック
        if !calendar.isDate(startOfLastDate, inSameDayAs: startOfToday) {
            scanCountToday = 0
            userDefaults.set(0, forKey: scanCountKey)
            userDefaults.set(now, forKey: lastScanDateKey)
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
        #if DEBUG
        // デバッグモードでは常にスキャン可能（テスト用）
        return true
        #else
        if currentPlan.dailyLimit == -1 { return true }
        return scanCountToday < currentPlan.dailyLimit
        #endif
    }
    
    var remainingFreeScans: Int {
        if currentPlan.dailyLimit == -1 { return 999 }
        return max(0, currentPlan.dailyLimit - scanCountToday)
    }
    
    /// プランを購入（StoreKit 2）
    @MainActor
    func purchase(plan: UserPlan, completion: @escaping (Bool) -> Void) {
        guard plan == .standard else {
            // フリープランは購入不要
            completion(false)
            return
        }
        
        guard let product = availableProducts.first(where: { $0.id == "standard_monthly" }) else {
            #if DEBUG
            errorMessage = String(format: L10n.planNotFound.text, availableProducts.count)
            #else
            errorMessage = L10n.purchaseErrorPlanNotFound.text
            #endif
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    let transaction = try Self.checkVerified(verification)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                    await MainActor.run {
                        self.isLoading = false
                        completion(true)
                    }
                    
                case .userCancelled:
                    await MainActor.run {
                        self.isLoading = false
                        completion(false)
                    }
                    
                case .pending:
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = L10n.purchasePending.text
                        completion(false)
                    }
                    
                @unknown default:
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = L10n.purchaseErrorGeneric.text
                        completion(false)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    let errorMsg = error.localizedDescription.isEmpty 
                        ? L10n.purchaseErrorGeneric.text 
                        : error.localizedDescription
                    self.errorMessage = errorMsg
                    completion(false)
                }
            }
        }
    }
    
    // 旧メソッド（互換性のため残すが、Standardへのアップグレードとする）
    @MainActor
    func purchasePro(completion: @escaping (Bool) -> Void) {
        purchase(plan: .standard, completion: completion)
    }
    
    /// 購入を復元（他のデバイスで購入した場合など）
    @MainActor
    func restorePurchases(completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Task {
            await updateSubscriptionStatus()
            let hadActiveSubscription = currentPlan == .standard
            
            isLoading = false
            
            if !hadActiveSubscription {
                errorMessage = L10n.restoreNoPurchases.text
            }
            
            completion(hadActiveSubscription)
        }
    }
}

// MARK: - Store Errors
enum StoreError: Error {
    case failedVerification
    case productNotFound
}
