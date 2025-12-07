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
    
    // テスト用広告ユニットID（本番環境では実際のIDに置き換える）
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313" // Googleのテスト用ID
    #else
    private let adUnitID = "YOUR_PRODUCTION_AD_UNIT_ID" // 本番用のAdMob広告ユニットIDをここに設定
    #endif
    
    private override init() {
        super.init()
    }
    
    /// AdMob SDKを初期化
    func initializeAdMob() {
        MobileAds.shared.start { [weak self] _ in
            print("AdMob初期化完了")
            self?.loadRewardedAd()
        }
    }
    
    /// リワード広告を読み込む
    func loadRewardedAd() {
        guard !isLoadingAd else { return }
        
        isLoadingAd = true
        isAdReady = false
        
        let request = Request()
        
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingAd = false
                
                if let error = error {
                    print("❌ リワード広告の読み込み失敗: \(error.localizedDescription)")
                    self.rewardedAd = nil
                    self.isAdReady = false
                    return
                }
                
                print("✅ リワード広告の読み込み成功")
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
            completion(false)
            return
        }
        
        self.onAdDismissed = completion
        
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

