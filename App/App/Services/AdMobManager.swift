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
        #if DEBUG
        // テストデバイスを設定
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["520039aee5efbde5ab82a7bc562e40b2"]
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
        
        print("📡 リワード広告を読み込み中...")
        
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingAd = false
                
                if let error = error {
                    print("❌ リワード広告の読み込み失敗: \(error.localizedDescription)")
                    print("   エラー詳細: \(error)")
                    self.rewardedAd = nil
                    
                    #if DEBUG
                    // デバッグ環境では広告なしで続行可能にする
                    print("🔧 DEBUG: 広告スキップモードを有効化")
                    self.isAdReady = true // デバッグ環境では広告なしでも続行
                    #else
                    self.isAdReady = false
                    #endif
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
        #if DEBUG
        // デバッグ環境: 広告がなくても続行
        guard let rewardedAd = rewardedAd else {
            print("🔧 DEBUG: 広告なしでスキップ（テスト用）")
            completion(true) // 広告なしでも成功として扱う
            loadRewardedAd() // 次の広告を読み込み試行
            return
        }
        #else
        // 本番環境: 広告が必須
        guard let rewardedAd = rewardedAd else {
            print("❌ リワード広告が準備できていません")
            completion(false)
            return
        }
        #endif
        
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

