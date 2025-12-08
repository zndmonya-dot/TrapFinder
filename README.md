# TrapFinder 🔍

**複雑な文書をAIが瞬時に要約・解析するiOSアプリ**

利用規約、プライバシーポリシー、契約書などの長文をスキャンし、重要なポイントやリスクを分かりやすく抽出します。

---

## 📱 App Store 申請情報

リリースに必要な情報は以下のファイルに集約されています。

- **申請用テキスト**: [APP_STORE_SUBMISSION_TEXT.md](./APP_STORE_SUBMISSION_TEXT.md)
  - タイトル、説明文、キーワード、カテゴリ、App Reviewメモなど
- **プライバシーポリシー**: [PRIVACY_POLICY.md](./PRIVACY_POLICY.md)
- **利用規約**: [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md)

---

## 🛠 開発環境とセットアップ

### **必須要件**
- Xcode 15.0+
- iOS 17.0+
- OpenAI API Key
- Google AdMob App ID

### **APIキーの設定**
`App/TrapFinder/Config/Secrets.xcconfig` を作成し、以下を設定してください：

```xcconfig
OPENAI_API_KEY = sk-proj-...
```

### **製品ID (Product IDs)**
App Store Connect および `PlanConfiguration.swift` で使用するID：

| プラン | ID | 価格 | 内容 |
|:---|:---|:---:|:---|
| **Standard** | `trapfinder_standard_v1` | ¥280/月 | 広告なし、50,000文字 |
| **Pro** | `trapfinder_pro_v1` | ¥580/月 | GPT-4o、50,000文字 |

---

## 🧪 テスト方法

### **課金テスト (StoreKit)**
1. Xcodeでスキーム編集 (`Product` > `Scheme` > `Edit Scheme`)
2. `Run` > `Options` > `StoreKit Configuration`
3. `Configuration.storekit` を選択
4. シミュレーターで実行すると、Sandbox環境で購入テストが可能

### **広告テスト**
- デバッグビルドではテスト用広告ユニットIDが自動的に使用されます。
- 広告読み込みエラー時は、自動的に広告をスキップして解析を実行するフォールバック機能が動作します。

---

## 📁 プロジェクト構成

```
App/
├── TrapFinder/
│   ├── Config/            # 設定ファイル (PlanConfigurationなど)
│   ├── Services/          # AdMob, OpenAI, OCR, StoreKit
│   ├── ViewModels/        # ロジック (ScannerViewModel)
│   └── Views/             # UIコンポーネント
├── Configuration.storekit # 課金テスト設定
└── TrapFinder.xcodeproj   # プロジェクトファイル
```

---

© 2025 TrapFinder
