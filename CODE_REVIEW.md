# コードレビュー - 懸念点と改善提案

## 🔴 重大な懸念点

### 1. **APIキーがソースコードにハードコードされている**
**場所**: `App/App/Config/AppConfig.swift`

```swift
static let openAIAPIKey = "sk-proj-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
```

**問題点**:
- APIキーがGitリポジトリにコミットされる可能性がある
- セキュリティリスクが高い
- `.gitignore`には含まれているが、既にコミットされている可能性

**推奨対応**:
- ✅ `.gitignore`に`AppConfig.swift`が含まれている（確認済み）
- ⚠️ 既にコミットされている場合は、Git履歴から削除する必要がある
- 💡 環境変数やXcodeの設定から読み込む方法を検討

---

## 🟡 中程度の懸念点

### 2. **アプリ名の不一致**
**場所**: `App/App/ContractCompanionApp.swift`

```swift
struct KudasApp: App {
```

**問題点**:
- アプリ名が`KudasApp`になっているが、実際のアプリ名は`TrapFinder`
- 混乱の原因になる可能性

**推奨対応**:
- `TrapFinderApp`に変更する

---

### 3. **エラーメッセージのハードコード**
**場所**: 複数箇所

**問題点**:
- 一部のエラーメッセージがハードコードされている
- ローカライゼーションされていない

**例**:
- `ScannerViewModel.swift:209`: `"解析エラー: \(error.localizedDescription)"`
- `StoreKitService.swift:241`: `"購入が保留中です。承認をお待ちください。"`

**推奨対応**:
- すべてのエラーメッセージを`Localization.swift`に移動
- 多言語対応を徹底

---

### 4. **デフォルトAIモデルが`gpt-4o`になっている**
**場所**: `App/App/Services/OpenAIService.swift:42`

```swift
func analyzeContract(text: String, model: String = "gpt-4o", completion: @escaping (Result<AnalysisResult, Error>) -> Void) {
```

**問題点**:
- デフォルトが`gpt-4o`だが、実際には`gpt-4o-mini`を使用している
- デフォルト値が使われる可能性がある

**推奨対応**:
- デフォルト値を`gpt-4o-mini`に変更するか、デフォルト値を削除して必須パラメータにする

---

### 5. **StoreKit 2のトランザクション監視タスクのキャンセル**
**場所**: `App/App/Services/StoreKitService.swift:88-99`

**問題点**:
- `listenForTransactions()`が`Task.detached`で実行されているが、エラーハンドリングが不十分
- 無限ループが続く可能性がある

**推奨対応**:
- エラーハンドリングを強化
- リトライロジックの追加を検討

---

## 🟢 軽微な懸念点

### 6. **未使用のインポート**
**場所**: `App/App/ContractCompanionApp.swift:2`

```swift
import SwiftData
```

**問題点**:
- `SwiftData`がインポートされているが使用されていない

**推奨対応**:
- 未使用のインポートを削除

---

### 7. **デバッグ用のprint文**
**場所**: 複数箇所

**問題点**:
- 本番環境でも`print`文が実行される
- ログが漏洩する可能性

**推奨対応**:
- `#if DEBUG`で囲むか、ログライブラリを使用

---

### 8. **URLSessionのキャンセル処理**
**場所**: `App/App/Services/OpenAIService.swift:62`, `App/App/Utils/WebPageHelper.swift:34`

**問題点**:
- `URLSession.dataTask`のキャンセル処理がない
- 画面を閉じた後もリクエストが続く可能性がある

**推奨対応**:
- `URLSessionDataTask`を保持して、適切にキャンセルする

---

### 9. **日付のリセット処理**
**場所**: `App/App/Services/StoreKitService.swift:165-175`

**問題点**:
- タイムゾーンの考慮が不十分な可能性がある
- 日付の境界での動作確認が必要

**推奨対応**:
- タイムゾーンを明示的に指定
- テストケースの追加

---

### 10. **プロンプトの長さ**
**場所**: `App/App/Services/OpenAIService.swift:112-209`

**問題点**:
- プロンプトが非常に長い（約100行）
- メンテナンスが困難

**推奨対応**:
- プロンプトを別ファイルに分離
- テンプレート化を検討

---

## ✅ 良い点

1. **メモリ管理**: `[weak self]`が適切に使用されている
2. **エラーハンドリング**: 基本的なエラーハンドリングが実装されている
3. **ローカライゼーション**: 大部分がローカライズされている
4. **アーキテクチャ**: MVVMパターンが適切に使用されている
5. **StoreKit 2**: 最新のAPIを使用している

---

## 📋 優先度別の対応リスト

### 高優先度（すぐに対応）
1. ✅ APIキーのセキュリティ対策（`.gitignore`は確認済み）
2. ⚠️ アプリ名の修正（`KudasApp` → `TrapFinderApp`）
3. ⚠️ デフォルトAIモデルの修正

### 中優先度（次回リリース前に対応）
4. エラーメッセージのローカライゼーション
5. StoreKit 2のエラーハンドリング強化
6. URLSessionのキャンセル処理

### 低優先度（時間があるときに）
7. 未使用のインポート削除
8. デバッグ用print文の整理
9. プロンプトのリファクタリング

---

## 🔍 追加で確認すべき点

1. **パフォーマンステスト**: 大量のテキスト処理時のメモリ使用量
2. **ネットワークエラーのテスト**: オフライン時の動作確認
3. **StoreKit 2のテスト**: サンドボックス環境での購入フローのテスト
4. **アクセシビリティ**: VoiceOverなどの対応状況
5. **App Store審査**: ガイドライン準拠の確認
