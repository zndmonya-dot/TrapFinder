import SwiftUI
import Combine

// MARK: - Language Manager
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("selectedLanguage") var languageCode: String = "ja" {
        didSet {
            objectWillChange.send()
        }
    }
    
    var currentLanguage: Language {
        get { Language(rawValue: languageCode) ?? .japanese }
        set { 
            languageCode = newValue.rawValue
            // 変更を確実に通知
            objectWillChange.send()
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
}

struct LocalizedString {
    let ja: String
    let en: String
    
    var text: String {
        switch LanguageManager.shared.currentLanguage {
        case .japanese: return ja
        case .english: return en
        }
    }
}

// 文字列リソースの定義
enum L10n {
    // Scanner View (Top Screen)
    static var scanning: LocalizedString { LocalizedString(ja: "テキストを読み取り中...", en: "Scanning text...") }
    static var analyzing: LocalizedString { LocalizedString(ja: "AIが内容をチェック中...", en: "AI is checking the content...") }
    static var scanTitle: LocalizedString { LocalizedString(ja: "ドキュメント解析", en: "Document Analysis") }
    static var scanDescription: LocalizedString { LocalizedString(ja: "あらゆる文書をチェック", en: "Scan any document") }
    static var camera: LocalizedString { LocalizedString(ja: "カメラ", en: "Camera") }
    static var photos: LocalizedString { LocalizedString(ja: "アルバム", en: "Photos") }
    static var pdf: LocalizedString { LocalizedString(ja: "PDF", en: "PDF") }
    static var scannedText: LocalizedString { LocalizedString(ja: "読み取ったテキスト", en: "Scanned Text") }
    static var analyzeButton: LocalizedString { LocalizedString(ja: "この内容をチェックする", en: "Check This Content") }
    static var error: LocalizedString { LocalizedString(ja: "エラー", en: "Error") }
    static var cameraPermissionTitle: LocalizedString { LocalizedString(ja: "カメラの許可が必要です", en: "Camera Permission Required") }
    static var cameraPermissionMsg: LocalizedString { LocalizedString(ja: "設定 > TrapFinder > カメラ をオンにしてください。", en: "Please enable Camera in Settings > TrapFinder.") }
    static var openSettings: LocalizedString { LocalizedString(ja: "設定を開く", en: "Open Settings") }
    static var cancel: LocalizedString { LocalizedString(ja: "キャンセル", en: "Cancel") }
    static var tapToChange: LocalizedString { LocalizedString(ja: "タップして変更", en: "Tap to change") }
    static var trash: LocalizedString { LocalizedString(ja: "削除", en: "Delete") }
    static var imageActions: LocalizedString { LocalizedString(ja: "画像の操作", en: "Image Actions") }
    static var retakeCamera: LocalizedString { LocalizedString(ja: "カメラで撮り直す", en: "Retake with Camera") }
    static var reselectPhoto: LocalizedString { LocalizedString(ja: "アルバムから選び直す", en: "Reselect from Photos") }
    static var deleteImage: LocalizedString { LocalizedString(ja: "選択を解除", en: "Deselect") }
    static var aiModelSelect: LocalizedString { LocalizedString(ja: "使用モデル", en: "AI Model") }
    static var highSpec: LocalizedString { LocalizedString(ja: "高性能 (4o)", en: "High-Spec (4o)") }
    static var standardSpec: LocalizedString { LocalizedString(ja: "標準 (mini)", en: "Standard (mini)") }
    
    // Top Screen Actions
    static var cameraScan: LocalizedString { LocalizedString(ja: "カメラでスキャン", en: "Scan with Camera") }
    static var cameraScanDesc: LocalizedString { LocalizedString(ja: "書類を撮影して解析", en: "Capture document to check") }
    static var albumSelect: LocalizedString { LocalizedString(ja: "アルバムから選択", en: "Select from Album") }
    static var albumSelectDesc: LocalizedString { LocalizedString(ja: "保存済みの画像を読み込み", en: "Import saved image") }
    static var pdfImport: LocalizedString { LocalizedString(ja: "PDFファイル", en: "PDF File") }
    static var pdfImportDesc: LocalizedString { LocalizedString(ja: "書類データを読み込み", en: "Import document file") }
    static var webPage: LocalizedString { LocalizedString(ja: "Webページ", en: "Web Page") }
    static var webPageDesc: LocalizedString { LocalizedString(ja: "URLから記事をチェック", en: "Check via URL") }
    static var textInput: LocalizedString { LocalizedString(ja: "テキスト入力", en: "Text Input") }
    static var textInputDesc: LocalizedString { LocalizedString(ja: "文章を直接貼り付け", en: "Paste text directly") }
    static var dataPrivacy: LocalizedString { LocalizedString(ja: "データは保存されず、AI学習にも使用されません", en: "Data is not saved or used for AI training") }
    static var readComplete: LocalizedString { LocalizedString(ja: "読み取り完了", en: "Scan Complete") }
    
    // Analysis Result
    static var analysisResult: LocalizedString { LocalizedString(ja: "チェック結果", en: "Check Result") }
    static var summary: LocalizedString { LocalizedString(ja: "概要", en: "Summary") }
    static var risksDetected: LocalizedString { LocalizedString(ja: "確認すべきポイント", en: "Points to Check") }
    static var high: LocalizedString { LocalizedString(ja: "要警戒", en: "ALERT") }
    static var medium: LocalizedString { LocalizedString(ja: "注意", en: "WARN") }
    static var low: LocalizedString { LocalizedString(ja: "確認", en: "NOTE") }
    static var info: LocalizedString { LocalizedString(ja: "情報", en: "INFO") }
    static var problem: LocalizedString { LocalizedString(ja: "内容", en: "Content") }
    static var suggestion: LocalizedString { LocalizedString(ja: "AIからのアドバイス", en: "AI Advice") }
    static var tapToCopy: LocalizedString { LocalizedString(ja: "タップしてコピー", en: "Tap to copy") }
    static var copied: LocalizedString { LocalizedString(ja: "コピーしました", en: "Copied") }
    static var seeSuggestion: LocalizedString { LocalizedString(ja: "詳細", en: "Details") }
    static var close: LocalizedString { LocalizedString(ja: "閉じる", en: "Close") }
    static var quote: LocalizedString { LocalizedString(ja: "該当箇所", en: "Quote") }
    static var explanation: LocalizedString { LocalizedString(ja: "解説", en: "Explanation") }
    
    // Settings
    static var settings: LocalizedString { LocalizedString(ja: "設定", en: "Settings") }
    static var language: LocalizedString { LocalizedString(ja: "言語設定", en: "Language") }
    static var currentPlan: LocalizedString { LocalizedString(ja: "現在のプラン", en: "Current Plan") }
    
    static var freePlan: LocalizedString { LocalizedString(ja: "フリープラン", en: "Free Plan") }
    static var standardPlan: LocalizedString { LocalizedString(ja: "スタンダードプラン", en: "Standard Plan") }
    static var proPlan: LocalizedString { LocalizedString(ja: "プロプラン", en: "Pro Plan") }
    
    static var upgradeToPro: LocalizedString { LocalizedString(ja: "アップグレード", en: "Upgrade") }
    static var dailyLimit: LocalizedString { LocalizedString(ja: "本日の残り回数", en: "Daily Limit Left") }
    static var limit3perDay: LocalizedString { LocalizedString(ja: "1日3回まで", en: "3 times / day") }
    static var unlimitedWithAds: LocalizedString { LocalizedString(ja: "動画広告視聴で回数無制限", en: "Unlimited scans with video ads") }
    static var noAds: LocalizedString { LocalizedString(ja: "広告非表示", en: "No ads") }
    static var charLimit5k: LocalizedString { LocalizedString(ja: "5,000文字まで", en: "Up to 5k chars") }
    static var times: LocalizedString { LocalizedString(ja: "回", en: "times") }
    static var appInfo: LocalizedString { LocalizedString(ja: "アプリ情報", en: "App Info") }
    static var version: LocalizedString { LocalizedString(ja: "バージョン", en: "Version") }
    static var developer: LocalizedString { LocalizedString(ja: "開発者", en: "Developer") }
    static var manageSub: LocalizedString { LocalizedString(ja: "サブスクリプションの管理", en: "Manage Subscription") }
    
    // Paywall
    static var upgradeTitle: LocalizedString { LocalizedString(ja: "プランを選択", en: "Choose Your Plan") }
    static var upgradeSubtitle: LocalizedString { LocalizedString(ja: "あなたの利用スタイルに合わせて\n最適なプランをお選びください", en: "Choose the plan that fits your style") }
    
    static var standardPrice: LocalizedString { LocalizedString(ja: "¥280 / 月", en: "¥280 / Month") }
    static var freePrice: LocalizedString { LocalizedString(ja: "無料", en: "Free") }
    static var proPrice: LocalizedString { LocalizedString(ja: "¥580 / 月", en: "¥580 / Month") }
    
    static var unlimitedScans: LocalizedString { LocalizedString(ja: "回数無制限", en: "Unlimited Scans") }
    static var standardAI: LocalizedString { LocalizedString(ja: "標準AI (GPT-4o-mini)", en: "Standard AI") }
    static var highPerformanceAI: LocalizedString { LocalizedString(ja: "高性能AI (GPT-4o)", en: "High-Performance AI") }
    static var charLimit10k: LocalizedString { LocalizedString(ja: "1回 10,000文字まで", en: "10k chars / scan") }
    static var charLimit100k: LocalizedString { LocalizedString(ja: "1回 50,000文字まで", en: "50k chars / scan") }
    static var charLimit50k: LocalizedString { LocalizedString(ja: "1回 50,000文字まで", en: "50k chars / scan") }
    static var limit10perDay: LocalizedString { LocalizedString(ja: "1日10回まで（制限到達時は自動で標準AIに切り替え）", en: "10 times / day (auto-switch to standard AI when limit reached)") }
    static var detailedAnalysis: LocalizedString { LocalizedString(ja: "より詳細なAI解説", en: "Detailed AI Analysis") }
    static var proFeatures: LocalizedString { LocalizedString(ja: "高性能AI + 無制限 (モデル選択可)", en: "High-Performance + Unlimited (Selectable)") }
    static var upgradeCta: LocalizedString { LocalizedString(ja: "アップグレードする", en: "Upgrade") }
    static var comingSoon: LocalizedString { LocalizedString(ja: "準備中", en: "Coming Soon") }
    static var recommended: LocalizedString { LocalizedString(ja: "おすすめ", en: "Recommended") }
    
    static var restorePurchase: LocalizedString { LocalizedString(ja: "購入を復元", en: "Restore Purchase") }
    static var terms: LocalizedString { LocalizedString(ja: "利用規約", en: "Terms of Service") }
    static var privacy: LocalizedString { LocalizedString(ja: "プライバシーポリシー", en: "Privacy Policy") }
    static var purchaseSuccessTitle: LocalizedString { LocalizedString(ja: "完了", en: "Success") }
    static var purchaseSuccessMsg: LocalizedString { LocalizedString(ja: "アップグレードが完了しました！", en: "Upgrade successful!") }
    static var purchaseErrorTitle: LocalizedString { LocalizedString(ja: "エラー", en: "Error") }
    static var purchaseErrorGeneric: LocalizedString { LocalizedString(ja: "購入処理中にエラーが発生しました", en: "An error occurred during purchase") }
    static var purchaseErrorPlanNotFound: LocalizedString { LocalizedString(ja: "プランが見つかりませんでした", en: "Plan not found") }
    static var purchaseCancelled: LocalizedString { LocalizedString(ja: "購入がキャンセルされました", en: "Purchase was cancelled") }
    static var restoreSuccess: LocalizedString { LocalizedString(ja: "購入を復元しました", en: "Purchases restored") }
    static var restoreNoPurchases: LocalizedString { LocalizedString(ja: "復元できる購入が見つかりませんでした", en: "No purchases found to restore") }
    static var purchasePending: LocalizedString { LocalizedString(ja: "購入が保留中です。承認をお待ちください。", en: "Purchase is pending. Please wait for approval.") }
    
    // Error Messages
    static var analysisError: LocalizedString { LocalizedString(ja: "解析エラー", en: "Analysis Error") }
    static var analysisErrorWithDescription: LocalizedString { LocalizedString(ja: "解析エラー: %@", en: "Analysis Error: %@") }
    static var cameraPermissionMissing: LocalizedString { LocalizedString(ja: "カメラの使用許可設定が不足しています。開発者にお問い合わせください。", en: "Camera permission setting is missing. Please contact the developer.") }
    static var pdfLoadError: LocalizedString { LocalizedString(ja: "PDFを読み込めませんでした", en: "Failed to load PDF") }
    static var invalidURL: LocalizedString { LocalizedString(ja: "http:// または https:// で始まる正しいURLを入力してください。", en: "Please enter a valid URL starting with http:// or https://") }
    static var textRecognitionError: LocalizedString { LocalizedString(ja: "文字を読み取れませんでした", en: "Failed to recognize text") }
    static var fileLoadError: LocalizedString { LocalizedString(ja: "ファイル読み込みエラー: %@", en: "File load error: %@") }
    static var webPageLoadError: LocalizedString { LocalizedString(ja: "ページからテキストを読み取れませんでした。ページが空か、アクセスできない可能性があります。", en: "Failed to read text from the page. The page may be empty or inaccessible.") }
    static var productLoadError: LocalizedString { LocalizedString(ja: "製品情報の取得に失敗しました: %@", en: "Failed to load product information: %@") }
    static var productLoadErrorDebug: LocalizedString { LocalizedString(ja: "製品情報の取得に失敗しました: %@\n\n【開発者向け】\nApp Store Connectで製品を設定しているか確認してください。", en: "Failed to load product information: %@\n\n[For Developers]\nPlease check if products are configured in App Store Connect.") }
    static var planNotFound: LocalizedString { LocalizedString(ja: "プランが見つかりませんでした。\n\n【開発者向け】\nApp Store Connectで製品ID「standard_monthly」を設定してください。\n\n現在の製品数: %d", en: "Plan not found.\n\n[For Developers]\nPlease configure product ID \"standard_monthly\" in App Store Connect.\n\nCurrent product count: %d") }
    static var httpError: LocalizedString { LocalizedString(ja: "HTTPエラー: %d", en: "HTTP Error: %d") }
    
    // Legal Disclaimer
    static var legalTitle: LocalizedString { LocalizedString(ja: "利用上の重要なお知らせ", en: "Important Legal Notice") }
    static var legalHeader1: LocalizedString { LocalizedString(ja: "1. 読解補助ツールです", en: "1. Reading Aid Only") }
    static var legalText1: LocalizedString { LocalizedString(ja: "本アプリは、文書の読解を補助するAIツールです。弁護士法に基づく法的助言や、契約の代行を行うものではありません。", en: "This app is an AI reading aid. It DOES NOT provide legal advice or attorney services.") }
    static var legalHeader2: LocalizedString { LocalizedString(ja: "2. 最終判断はご自身で", en: "2. Your Responsibility") }
    static var legalText2: LocalizedString { LocalizedString(ja: "AIの解析結果は完全ではありません。同意ボタンを押す前や契約書にサインする前の最終確認は、必ずご自身の責任で行ってください。", en: "AI results are not perfect. Final decisions should be made at your own risk.") }
    static var legalHeader3: LocalizedString { LocalizedString(ja: "3. 係争案件への利用禁止", en: "3. No Use for Disputes") }
    static var legalText3: LocalizedString { LocalizedString(ja: "法的トラブルが発生している案件の証拠として、本アプリの結果を使用することはできません。", en: "Results cannot be used as evidence in legal disputes.") }
    static var legalHeader4: LocalizedString { LocalizedString(ja: "4. 機密情報の扱い", en: "4. Data Privacy") }
    static var legalText4: LocalizedString { LocalizedString(ja: "読み取られたデータはOpenAI APIを通じて処理されます。機密性の高い情報の入力には十分ご注意ください。", en: "Data is processed via OpenAI API. Please be careful with confidential information.") }
    static var agreeButton: LocalizedString { LocalizedString(ja: "上記に同意して利用を開始する", en: "I Agree & Start Using") }
    
    // Settings View
    static var general: LocalizedString { LocalizedString(ja: "一般", en: "General") }
    static var planManagement: LocalizedString { LocalizedString(ja: "プラン管理", en: "Plan Management") }
    // selectPlanは削除（重複のため）
    static var support: LocalizedString { LocalizedString(ja: "サポート", en: "Support") }
    static var remainingScans: LocalizedString { LocalizedString(ja: "残り %d 回", en: "%d remaining") }
    static var unlimitedScansText: LocalizedString { LocalizedString(ja: "スキャン回数無制限", en: "Unlimited Scans") }
    
    // Scanner View
    static var tokenLimitTitle: LocalizedString { LocalizedString(ja: "文字数が多すぎます", en: "Text Too Long") }
    static var tokenLimitMessage: LocalizedString { LocalizedString(ja: "読み取った文字数が50,000文字を超えています。\nすべて解析すると時間がかかり、エラーになる可能性があります。\n\n先頭の50,000文字だけ解析しますか？", en: "The scanned text exceeds 50,000 characters.\nAnalyzing all of it may take time and could cause errors.\n\nWould you like to analyze only the first 50,000 characters?") }
    static var analyzeTruncated: LocalizedString { LocalizedString(ja: "先頭のみ解析する", en: "Analyze First Part Only") }
    static var webPageInputHint: LocalizedString { LocalizedString(ja: "利用規約やプライバシーポリシーのページURLを入力してください。", en: "Enter the URL of the terms of service or privacy policy page.") }
    static var load: LocalizedString { LocalizedString(ja: "読み込む", en: "Load") }
    static var textInputLimit: LocalizedString { LocalizedString(ja: "※50,000文字まで入力可能です", en: "※Up to 50,000 characters can be entered") }
    static var done: LocalizedString { LocalizedString(ja: "完了", en: "Done") }
    
    // Analysis Result View
    static var disclaimer: LocalizedString { LocalizedString(ja: "免責事項", en: "Disclaimer") }
    static var items: LocalizedString { LocalizedString(ja: "件", en: "items") }
    static var reportTitle: LocalizedString { LocalizedString(ja: "【TrapFinder 解析レポート】", en: "【TrapFinder Analysis Report】") }
    static var reportDate: LocalizedString { LocalizedString(ja: "実施日", en: "Date") }
    static var documentType: LocalizedString { LocalizedString(ja: "■ 文書の種類", en: "■ Document Type") }
    static var summarySection: LocalizedString { LocalizedString(ja: "■ 概要", en: "■ Summary") }
    static var checkPoints: LocalizedString { LocalizedString(ja: "■ 確認ポイント（%d件）", en: "■ Check Points (%d items)") }
    static var noIssuesFound: LocalizedString { LocalizedString(ja: "特筆すべき確認事項は検出されませんでした。", en: "No notable issues were detected.") }
    static var originalText: LocalizedString { LocalizedString(ja: "【原文】", en: "【Original Text】") }
    static var explanationSection: LocalizedString { LocalizedString(ja: "【解説】", en: "【Explanation】") }
    static var advice: LocalizedString { LocalizedString(ja: "【アドバイス】", en: "【Advice】") }
    static var reportFooter: LocalizedString { LocalizedString(ja: "※このレポートはAIによって生成された読解補助情報です。\n※法的助言ではありません。最終的な判断はご自身で行ってください。", en: "※This report is AI-generated reading assistance information.\n※This is not legal advice. Please make final decisions at your own discretion.") }
    static var noIssuesTitle: LocalizedString { LocalizedString(ja: "特筆すべき確認事項なし", en: "No Notable Issues") }
    static var noIssuesMessage: LocalizedString { LocalizedString(ja: "AIによるチェックでは、特に注意すべき点は見つかりませんでした。", en: "The AI check found no points requiring special attention.") }
    
    // How to Use Guide
    static var howToUseTitle: LocalizedString { LocalizedString(ja: "使い方", en: "How to Use") }
    static var howToUseTapToOpen: LocalizedString { LocalizedString(ja: "タップして開く", en: "Tap to expand") }
    static var howToUseTapToClose: LocalizedString { LocalizedString(ja: "タップして閉じる", en: "Tap to collapse") }
    static var howToUseStep1: LocalizedString { LocalizedString(ja: "1. 文書をスキャン", en: "1. Scan Document") }
    static var howToUseStep1Desc: LocalizedString { LocalizedString(ja: "カメラ、アルバム、PDF、URL、テキストから選択", en: "Choose from camera, album, PDF, URL, or text") }
    static var howToUseStep2: LocalizedString { LocalizedString(ja: "2. AIが自動解析", en: "2. AI Analyzes") }
    static var howToUseStep2Desc: LocalizedString { LocalizedString(ja: "文書の種類を自動判定し、注意点をチェック", en: "Automatically detects document type and checks for issues") }
    static var howToUseStep3: LocalizedString { LocalizedString(ja: "3. 結果を確認", en: "3. Review Results") }
    static var howToUseStep3Desc: LocalizedString { LocalizedString(ja: "分かりやすい解説とアドバイスを表示", en: "View easy-to-understand explanations and advice") }
    
    // Language Settings
    static var languageSelectionHint: LocalizedString { LocalizedString(ja: "アプリの表示言語を選択してください", en: "Select your preferred language") }
}
