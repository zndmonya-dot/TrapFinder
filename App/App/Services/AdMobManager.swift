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
    
    private var rewardedAd: RewardedAd?
    private var onAdDismissed: ((Bool) -> Void)?
    private var adLoadRetryCount = 0
    private let maxAdLoadRetries = 3 // 最大リトライ回数
    
    // 本番用広告ユニットID
    private let adUnitID = "ca-app-pub-2477585454032901/5825870847"
    
    private override init() {
        super.init()
    }
    
    /// AdMob SDKを初期化
    func initializeAdMob() {
        #if DEBUG
        // テストデバイスを設定（シミュレーターごとに異なる場合があります）
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "520039aee5efbde5ab82a7bc562e40b2",  // 旧デバイスID
            "5282e503fae41f3d8fee42f3c23900d4"   // 新デバイスID
        ]
        print("🔧 テストデバイスIDを設定しました")
        #endif
        
        MobileAds.shared.start { [weak self] _ in
            print("✅ AdMob初期化完了")
            self?.loadRewardedAd()
        }
    }
    
    /// リワード広告を読み込む
    func loadRewardedAd() {
        guard !isLoadingAd else {
            print("⏳ 広告読み込み中...")
            return
        }
        
        isLoadingAd = true
        isAdReady = false
        
        let request = Request()
        
        print("📡 リワード広告を読み込み中... (試行: \(adLoadRetryCount + 1)/\(maxAdLoadRetries + 1))")
        print("   広告ユニットID: \(adUnitID)")
        
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingAd = false
                
                if let error = error {
                    print("❌ リワード広告の読み込み失敗: \(error.localizedDescription)")
                    print("   エラー詳細: \(error)")
                    self.rewardedAd = nil
                    self.isAdReady = false
                    
                    #if DEBUG
                    // デバッグ環境: 最大リトライ回数まで再試行
                    if self.adLoadRetryCount < self.maxAdLoadRetries {
                        self.adLoadRetryCount += 1
                        print("🔄 5秒後に広告読み込みを再試行します... (\(self.adLoadRetryCount)/\(self.maxAdLoadRetries))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.loadRewardedAd()
                        }
                    } else {
                        print("⚠️ 広告の読み込みリトライ上限に達しました")
                        print("💡 ヒント: シミュレーターを再起動するか、ネットワーク接続を確認してください")
                    }
                    #endif
                    return
                }
                
                print("✅ リワード広告の読み込み成功")
                self.adLoadRetryCount = 0 // 成功したらリトライカウントをリセット
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdReady = true
            }
        }
    }
    
    /// リワード広告を表示
    /// - Parameters:
    ///   - rootViewController: 広告を表示する親ViewController
    ///   - completion: 広告が閉じられた後のコールバック（報酬を獲得したかどうか）
    func showRewardedAd(from rootViewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            print("❌ リワード広告が準備できていません")
            print("   広告を再読み込みしています...")
            completion(false)
            loadRewardedAd() // 広告を再読み込み
            return
        }
        
        self.onAdDismissed = completion
        
        print("📺 リワード広告を表示中...")
        rewardedAd.present(from: rootViewController) { [weak self] in
            let reward = rewardedAd.adReward
            print("✅ ユーザーが報酬を獲得: \(reward.amount) \(reward.type)")
            self?.handleRewardEarned()
        }
    }
    
    /// 報酬を獲得した際の処理
    private func handleRewardEarned() {
        // 次の広告を事前読み込み
        loadRewardedAd()
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

