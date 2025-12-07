# Google AdMob 広告実装ガイド

## 📱 実装完了内容

✅ AdMobManagerクラスの作成
✅ リワード広告の実装
✅ 無料プランでの広告視聴フローの実装
✅ UIボタンの更新（「広告を見て解析」）
✅ Info.plistへのAdMob設定追加

---

## 🚀 次に必要な手順

### 1. Google AdMob SDKをXcodeに追加

#### **方法A: Swift Package Managerで追加（推奨）**

1. Xcodeでプロジェクトを開く
2. **File → Add Package Dependencies...**
3. 検索バーに以下のURLを入力:
   ```
   https://github.com/googleads/swift-package-manager-google-mobile-ads.git
   ```
4. **Dependency Rule**: "Up to Next Major Version" (8.0.0 以上)
5. **Add Package**をクリック
6. **GoogleMobileAds**にチェックを入れて**Add Package**

---

### 2. Google AdMobアカウントの設定

#### **2-1. AdMobアカウント作成**
1. [AdMob](https://admob.google.com/)にアクセス
2. Googleアカウントでサインイン
3. 新規アプリを登録:
   - アプリ名: **TrapFinder**
   - プラットフォーム: **iOS**
   - App Store URL: （審査通過後に追加）

#### **2-2. 広告ユニットの作成**
1. AdMobダッシュボードで **広告ユニット → 広告ユニットを追加**
2. **リワード**を選択
3. 広告ユニット名: 例）`TrapFinder - リワード広告`
4. **作成**をクリック
5. 表示される**広告ユニットID**と**App ID**をコピー

---

### 3. 本番用の広告IDに置き換え

#### **3-1. Info.plist の更新**

`App/App/Info.plist` を開き、以下を更新:

```xml
<!-- AdMob App ID（テスト用、本番環境では実際のIDに置き換える） -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

↓ **本番用のApp IDに置き換え**

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-YOUR_ACTUAL_APP_ID</string>
```

#### **3-2. AdMobManager.swift の更新**

`App/App/Services/AdMobManager.swift` を開き、以下を更新:

```swift
#else
private let adUnitID = "YOUR_PRODUCTION_AD_UNIT_ID" // 本番用のAdMob広告ユニットIDをここに設定
#endif
```

↓ **本番用の広告ユニットIDに置き換え**

```swift
#else
private let adUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ" // AdMobで取得した広告ユニットID
#endif
```

---

### 4. App Tracking Transparency（ATT）の実装（iOS 14以降）

広告追跡の許可を求めるため、アプリ起動時にATTダイアログを表示します。

#### **ContractCompanionApp.swift の更新**

`App/App/ContractCompanionApp.swift` に以下を追加:

```swift
import SwiftUI
import AppTrackingTransparency
import AdSupport

@main
struct TrapFinderApp: App {
    @StateObject private var storeKitService = StoreKitService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var adMobManager = AdMobManager.shared
    
    init() {
        // AdMob SDKを初期化
        AdMobManager.shared.initializeAdMob()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(storeKitService)
                .environmentObject(languageManager)
                .environmentObject(adMobManager)
                .onAppear {
                    requestTrackingPermission()
                }
        }
    }
    
    private func requestTrackingPermission() {
        // iOS 14以降でトラッキング許可をリクエスト
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("✅ トラッキング許可")
                case .denied, .restricted, .notDetermined:
                    print("❌ トラッキング拒否またはステータス不明")
                @unknown default:
                    break
                }
            }
        }
    }
}
```

---

## 🧪 テスト方法

### **デバッグ環境でのテスト**
- 現在、テスト用広告IDを使用しているため、デバッグビルドで広告が表示されます
- 無料プランで「広告を見て解析」ボタンをタップ
- テスト広告が表示されることを確認
- 広告視聴後、AI解析が実行されることを確認

### **本番環境でのテスト**
- 本番用の広告IDに置き換え後、TestFlightでテスト
- 実際の広告が表示されることを確認

---

## ⚠️ 注意事項

### **1. テスト広告IDを本番環境で使用しない**
- Googleのポリシー違反になります
- 必ず本番用の広告IDに置き換えてください

### **2. 広告の表示頻度**
- 無料プランのユーザーは解析ごとに広告を視聴
- 広告の読み込みに失敗した場合のエラーハンドリングを実装済み

### **3. プライバシーポリシーの更新**
- 広告を使用する場合、プライバシーポリシーに以下を記載:
  - 広告配信のためにGoogle AdMobを使用していること
  - 広告識別子（IDFA）を収集する可能性があること
  - ユーザーがトラッキングを拒否できること

---

## 📊 収益化の見込み

### **CPM（1,000インプレッションあたりの収益）**
- 日本市場: 平均 ¥200-500
- リワード広告: eCPM ¥500-1,500（高め）

### **収益シミュレーション**
| DAU | 広告視聴/ユーザー | 月間広告視聴数 | 月間収益（eCPM ¥800） |
|-----|------------------|----------------|----------------------|
| 100 | 3回/日 | 9,000 | ¥7,200 |
| 500 | 3回/日 | 45,000 | ¥36,000 |
| 1,000 | 3回/日 | 90,000 | ¥72,000 |

---

## ✅ 完了チェックリスト

- [ ] Google AdMob SDKをSwift Package Managerで追加
- [ ] AdMobアカウントを作成
- [ ] 広告ユニットを作成（リワード広告）
- [ ] Info.plistの本番用App IDに更新
- [ ] AdMobManager.swiftの本番用広告ユニットIDに更新
- [ ] ATT（App Tracking Transparency）の実装
- [ ] デバッグ環境でテスト広告の表示確認
- [ ] TestFlightで本番広告の表示確認
- [ ] プライバシーポリシーに広告に関する記載を追加

---

## 🎯 次のステップ

1. **Swift Package ManagerでAdMob SDKを追加**
2. **AdMobアカウントを作成し、広告ユニットを取得**
3. **本番用IDに置き換え**
4. **ATTを実装**
5. **テスト**
6. **App Storeに提出**

頑張ってください！🚀

