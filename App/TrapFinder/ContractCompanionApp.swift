import SwiftUI
import AppTrackingTransparency
import AdSupport

@main
struct TrapFinderApp: App {
    @StateObject private var storeKitService = StoreKitService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var adMobManager = AdMobManager.shared
    @State private var hasRequestedTracking = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // アプリ全体をライトモードに固定
                .environmentObject(storeKitService)
                .environmentObject(languageManager)
                .environmentObject(adMobManager)
                .onAppear {
                    // アプリ起動後、少し待ってからトラッキング許可をリクエスト
                    if !hasRequestedTracking {
                        hasRequestedTracking = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            requestTrackingPermissionAndInitializeAds()
                        }
                    }
                }
        }
    }
    
    private func requestTrackingPermissionAndInitializeAds() {
        // iOS 14以降でトラッキング許可をリクエスト
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        print("✅ トラッキング許可")
                    case .denied:
                        print("❌ トラッキング拒否")
                    case .restricted:
                        print("⚠️ トラッキング制限")
                    case .notDetermined:
                        print("❓ トラッキング未決定")
                    @unknown default:
                        print("❓ トラッキング状態不明")
                    }
                    
                    // トラッキング許可の結果に関わらず、AdMobを初期化
                    print("📱 AdMobを初期化します...")
                    AdMobManager.shared.initializeAdMob()
                }
            }
        } else {
            // iOS 14未満の場合は直接初期化
            print("📱 AdMobを初期化します（iOS 14未満）...")
            AdMobManager.shared.initializeAdMob()
        }
    }
}
