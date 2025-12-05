# App Store リリースチェックリスト

## 📱 必須項目

### 1. スクリーンショット（必須）
以下のサイズでスクリーンショットが必要です：

#### iPhone用（6.7インチ - iPhone 14 Pro Max等）
- **必要枚数**: 最低3枚、推奨5-10枚
- **サイズ**: 1290 x 2796 ピクセル
- **推奨シーン**:
  1. メイン画面（スキャン方法選択）
  2. スキャン中（進捗表示）
  3. 解析結果画面（リスク項目の表示）
  4. 解析結果の詳細（展開されたカード）
  5. 設定画面

#### iPhone用（6.5インチ - iPhone 11 Pro Max等）
- **サイズ**: 1242 x 2688 ピクセル

#### iPad用（12.9インチ）
- **サイズ**: 2048 x 2732 ピクセル

### 2. App Store Connectでの設定項目

#### 基本情報
- **アプリ名**: TrapFinder（または希望の名前）
- **サブタイトル**: 契約書・規約をAI解析
- **カテゴリ**: 
  - プライマリ: ビジネス または ユーティリティ
  - セカンダリ: ライフスタイル または 生産性

#### 説明文（日本語）
```
TrapFinderは、契約書や利用規約などの文書をAIが解析し、ユーザーにとって注意すべきポイントを分かりやすく提示する万能ドキュメント解析AIです。

【主な機能】
• カメラ撮影、PDF、テキスト入力、URL入力など、様々な方法で文書を取り込み
• AIが文書を自動解析し、重要なポイントを抽出
• 金額、期間、権利・義務など、カテゴリ別に整理された解析結果
• 詳細な解説と実用的なアドバイスを提供

【こんな方におすすめ】
• 契約書や規約を読むのが面倒な方
• 重要なポイントを見逃したくない方
• 隠れた費用や条件を確認したい方

【プラン】
• フリープラン: 10,000文字/回まで無料
• スタンダードプラン: 80,000文字/回、無制限スキャン（¥780/月）
• プロプラン: GPT-4o使用、1日10回まで（¥1,180/月）

※本アプリは法的助言を提供するものではありません。あくまでユーザー自身の読解と判断をサポートする補助ツールです。
```

#### 説明文（英語）
```
TrapFinder is an AI-powered document analysis tool that analyzes contracts and terms of service to highlight important points users should be aware of.

【Key Features】
• Capture documents via camera, PDF, text input, or URL
• AI automatically analyzes documents and extracts key points
• Organized analysis results by category: costs, terms, rights & obligations
• Detailed explanations and practical advice

【Perfect For】
• Those who find reading contracts and terms tedious
• Those who don't want to miss important points
• Those who want to check for hidden fees and conditions

【Plans】
• Free Plan: Up to 10,000 characters per scan
• Standard Plan: 80,000 characters per scan, unlimited scans (¥780/month)
• Pro Plan: GPT-4o, up to 10 times per day (¥1,180/month)

※This app does not provide legal advice. It is a supplementary tool to support users' own reading and judgment.
```

#### キーワード
- 日本語: 契約書,規約,AI解析,文書解析,リスク検出,契約チェック,利用規約
- 英語: contract,terms,AI analysis,document analysis,risk detection

#### プライバシーポリシーURL（推奨）
- プライバシーポリシーを公開するURLが必要です
- GitHub PagesやWebサイトに公開する必要があります

#### サポートURL（推奨）
- サポートページのURL
- GitHubのIssuesページでも可

### 3. アプリ情報の確認

#### Bundle ID
- `com.zndmonya.TrapFinder`

#### バージョン情報
- **Marketing Version**: 1.0
- **Build Number**: 1

#### 必要な権限
- カメラ（NSCameraUsageDescription）: ✅ 設定済み

## 📋 リリース前の確認事項

### 技術的な確認
- [ ] 実機で動作確認（特にPDF処理とAI解析）
- [ ] APIキーが正しく設定されているか確認
- [ ] エラーハンドリングが適切に動作するか確認
- [ ] メモリリークがないか確認（Instrumentsで確認）

### App Store Connectでの確認
- [ ] スクリーンショットをアップロード
- [ ] 説明文を入力
- [ ] キーワードを設定
- [ ] プライバシーポリシーURLを設定
- [ ] サポートURLを設定
- [ ] 年齢制限を設定（17+推奨、法的内容を含むため）
- [ ] カテゴリを設定

### ストア情報の確認
- [ ] アプリ名が適切か
- [ ] 説明文に誤字がないか
- [ ] 価格設定が正しいか（¥780/月、¥1,180/月）
- [ ] 製品IDが正しいか（`standard_monthly`、`pro_monthly`）

## 🚀 リリース手順

### 1. スクリーンショットの準備
1. 実機またはシミュレーターでアプリを起動
2. 各画面をキャプチャ
3. 画像編集ソフトでサイズを調整（必要に応じて）
4. App Store Connectにアップロード

### 2. Xcodeでのアーカイブ
1. **Product > Scheme > Edit Scheme** で **Release** を選択
2. **Product > Archive** を実行
3. Archive完了後、**Distribute App** を選択
4. **App Store Connect** を選択
5. **Upload** を選択

### 3. App Store Connectでの提出
1. App Store Connectにログイン
2. **マイApp** > **TrapFinder** を選択
3. **新しいバージョン** を作成
4. スクリーンショットと説明文を入力
5. **審査に提出** をクリック

## ⚠️ 注意事項

- **初回リリース**: 審査に1-2週間かかる場合があります
- **スクリーンショット**: 最低3枚は必須です
- **プライバシーポリシー**: 必須ではありませんが、推奨されます
- **テスト**: TestFlightで事前にテストすることを推奨します

