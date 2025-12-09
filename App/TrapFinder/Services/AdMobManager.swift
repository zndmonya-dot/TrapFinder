import Foundation
import GoogleMobileAds
import UIKit
import Combine

/// Google AdMobのリワード広告を管理するクラス
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    // ObservableObjectの要件を満たすために明示的に定義
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    var isAdReady = false {
        willSet { objectWillChange.send() }
    }
    
    var isLoadingAd = false {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - Properties
    
    private var rewardedAd: RewardedAd?
    private var onAdDismissed: ((Bool) -> Void)?
    private var adLoadRetryCount = 0
    
    // MARK: - Constants
    
    private enum AdConstants {
        // 本番広告ユニット（デバッグ／リリース共通で使用）
        static let adUnitID = "ca-app-pub-2477585454032901/5825870847"
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 5.0
        static let testDeviceIDs = [
            "520039aee5efbde5ab82a7bc562e40b2",
            "5282e503fae41f3d8fee42f3c23900d4"
        ]
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Initialization
    
    /// AdMob SDKを初期化
    func initializeAdMob() {
        #if DEBUG
        configureTestDevices()
        #endif
        
        MobileAds.shared.start { [weak self] _ in
            print("✅ AdMob初期化完了")
            self?.loadRewardedAd()
        }
    }
    
    #if DEBUG
    private func configureTestDevices() {
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = AdConstants.testDeviceIDs
        print("🔧 テストデバイスIDを設定しました: \(AdConstants.testDeviceIDs)")
    }
    #endif
    
    // MARK: - Ad Loading
    
    /// リワード広告を読み込む
    func loadRewardedAd() {
        guard !isLoadingAd else {
            print("⏳ 広告読み込み中...")
            return
        }
        
        isLoadingAd = true
        isAdReady = false
        
        logAdLoadAttempt()
        
        let request = Request()
        RewardedAd.load(with: AdConstants.adUnitID, request: request) { [weak self] ad, error in
            self?.handleAdLoadResult(ad: ad, error: error)
        }
    }
    
    private func handleAdLoadResult(ad: RewardedAd?, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isLoadingAd = false
            
            if let error = error {
                self.handleAdLoadFailure(error: error)
            } else if let ad = ad {
                self.handleAdLoadSuccess(ad: ad)
            }
        }
    }
    
    private func handleAdLoadSuccess(ad: RewardedAd) {
        print("✅ リワード広告の読み込み成功")
        adLoadRetryCount = 0
        rewardedAd = ad
        rewardedAd?.fullScreenContentDelegate = self
        isAdReady = true
    }
    
    private func handleAdLoadFailure(error: Error) {
        print("❌ リワード広告の読み込み失敗: \(error.localizedDescription)")
        print("   エラー詳細: \(error)")
        rewardedAd = nil
        isAdReady = false

        attemptRetryIfPossible()
    }
    
    private func attemptRetryIfPossible() {
        guard adLoadRetryCount < AdConstants.maxRetries else {
            print("⚠️ 広告の読み込みリトライ上限に達しました")
            print("💡 ヒント: シミュレーターを再起動するか、ネットワーク接続を確認してください")
            return
        }
        
        adLoadRetryCount += 1
        print("🔄 \(Int(AdConstants.retryDelay))秒後に広告読み込みを再試行します... (\(adLoadRetryCount)/\(AdConstants.maxRetries))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + AdConstants.retryDelay) { [weak self] in
            self?.loadRewardedAd()
        }
    }
    
    private func logAdLoadAttempt() {
        print("📡 リワード広告を読み込み中... (試行: \(adLoadRetryCount + 1)/\(AdConstants.maxRetries + 1))")
        print("   広告ユニットID: \(AdConstants.adUnitID)")
    }
    
    // MARK: - Ad Presentation
    
    /// リワード広告を表示
    /// - Parameters:
    ///   - rootViewController: 広告を表示する親ViewController
    ///   - completion: 広告が閉じられた後のコールバック（報酬を獲得したかどうか）
    func showRewardedAd(from rootViewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            handleAdNotReady(completion: completion)
            return
        }
        
        onAdDismissed = completion
        presentAd(rewardedAd, from: rootViewController)
    }
    
    private func handleAdNotReady(completion: @escaping (Bool) -> Void) {
        print("❌ リワード広告が準備できていません")
        print("   広告を再読み込みしています...")
        completion(false)
        loadRewardedAd()
    }
    
    private func presentAd(_ ad: RewardedAd, from viewController: UIViewController) {
        print("📺 リワード広告を表示中...")
        ad.present(from: viewController) { [weak self] in
            self?.handleAdReward(ad.adReward)
        }
    }
    
    private func handleAdReward(_ reward: AdReward) {
        print("✅ ユーザーが報酬を獲得: \(reward.amount) \(reward.type)")
        loadRewardedAd() // 次の広告を事前読み込み
    }
}

// MARK: - FullScreenContentDelegate

extension AdMobManager: FullScreenContentDelegate {
    /// 広告が表示された
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("📊 広告インプレッション記録")
    }
    
    /// 広告が閉じられた
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🚪 広告が閉じられました")
        
        // 報酬を獲得して閉じた場合はtrue
        let didEarnReward = rewardedAd != nil
        onAdDismissed?(didEarnReward)
        onAdDismissed = nil
        
        // 次の広告を読み込む
        loadRewardedAd()
    }
    
    /// 広告の表示に失敗
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ 広告表示エラー: \(error.localizedDescription)")
        onAdDismissed?(false)
        onAdDismissed = nil
        
        // 再読み込みを試行
        loadRewardedAd()
    }
}

