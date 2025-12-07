import Foundation
import Combine
import SwiftUI
import Vision
import VisionKit
import AVFoundation
import PDFKit

enum FlowState: Equatable {
    case idle
    case scanning(page: Int, total: Int)
    case analyzing
    case error(String)
}

enum ActiveSheet: Identifiable {
    case analysisResult
    case imagePicker
    case textInput
    case urlInput
    case paywall
    case cameraAlert
    case tokenLimitAlert
    
    var id: Int {
        switch self {
        case .analysisResult: return 1
        case .imagePicker: return 2
        case .textInput: return 3
        case .urlInput: return 4
        case .paywall: return 5
        case .cameraAlert: return 6
        case .tokenLimitAlert: return 7
        }
    }
}

class ScannerViewModel: ObservableObject {
    @Published var scannedText = ""
    @Published var flowState: FlowState = .idle
    @Published var activeSheet: ActiveSheet?
    @Published var analysisResult: AnalysisResult?
    
    // 進捗表示用
    @Published var analysisProgressMessage: String = ""
    
    // UI State Flags
    @Published var showingCamera = false
    @Published var showingFileImporter = false
    
    @Published var selectedImage: UIImage?
    
    private var cancellables = Set<AnyCancellable>()
    private let ocrService: OCRService
    private let openAIService: OpenAIService
    private let aiService: OpenAIAnalyzing
    private let storeKitService: StoreKitService
    private let webPageHelper: WebPageHelper
    private let adMobManager: AdMobManager
    private var analysisTask: Task<Void, Never>?
    
    // 進捗表示用のタイマー
    private var progressTimer: Timer?

    init(
        aiService: OpenAIAnalyzing = OpenAIService.shared,
        ocrService: OCRService = .shared,
        openAIService: OpenAIService = .shared,
        storeKitService: StoreKitService = .shared,
        webPageHelper: WebPageHelper = .shared,
        adMobManager: AdMobManager = .shared
    ) {
        self.aiService = aiService
        self.ocrService = ocrService
        self.openAIService = openAIService
        self.storeKitService = storeKitService
        self.webPageHelper = webPageHelper
        self.adMobManager = adMobManager
    }
    
    /// 解析をキャンセル
    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        openAIService.cancelCurrentRequest()
        webPageHelper.cancelCurrentRequest()
        flowState = .idle
        stopProgressTimer()
    }
    
    /// 進捗タイマーを開始
    private func startProgressTimer() {
        stopProgressTimer()
        analysisProgressMessage = L10n.analyzing.text
        flowState = .analyzing
        
        var elapsedSeconds = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, case .analyzing = self.flowState else {
                timer.invalidate()
                return
            }
            
            elapsedSeconds += 1
            
            // 時間経過に応じてメッセージを更新
            let currentLanguage = LanguageManager.shared.currentLanguage
            switch elapsedSeconds {
            case 0..<5:
                self.analysisProgressMessage = currentLanguage == .japanese 
                    ? "文書を読み込んでいます..."
                    : "Reading document..."
            case 5..<15:
                self.analysisProgressMessage = currentLanguage == .japanese 
                    ? "重要なポイントを検出中..."
                    : "Detecting important points..."
            case 15..<30:
                self.analysisProgressMessage = currentLanguage == .japanese 
                    ? "詳細を確認中..."
                    : "Checking details..."
            case 30..<60:
                self.analysisProgressMessage = currentLanguage == .japanese 
                    ? "項目を整理中..."
                    : "Organizing items..."
            default:
                self.analysisProgressMessage = currentLanguage == .japanese 
                    ? "最終チェック中..."
                    : "Final check..."
            }
        }
    }
    
    /// 進捗タイマーを停止
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        analysisProgressMessage = ""
    }
    
    func checkCameraPermission() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            #if DEBUG
            print("ERROR: NSCameraUsageDescription not found in Info.plist")
            #endif
            self.flowState = .error(L10n.cameraPermissionMissing.text)
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showingCamera = true
                    } else {
                        self.activeSheet = .cameraAlert
                    }
                }
            }
        case .denied, .restricted:
            self.activeSheet = .cameraAlert
        @unknown default:
            break
        }
    }
    
    func scanImage(_ image: UIImage) {
        scanImages([image])
    }
    
    func scanImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        startScanning(totalPages: images.count)
        
        Task { [weak self] in
            await self?.processImagesSequentially(images: images)
        }
    }
    
    func scanPDF(url: URL) {
        // PDF読み込み開始（ページ数は不明なのでanalyzing状態にする）
        flowState = .analyzing
        
        Task { [weak self] in
            guard let self else { return }
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // PDFを画像に変換（エラーハンドリングを追加）
            let images: [UIImage]
            do {
                images = try await convertPDFToImages(url: url)
            } catch let error as PDFConversionError {
                await MainActor.run {
                    let errorMsg: String
                    switch error {
                    case .failedToLoadDocument:
                        errorMsg = "PDFファイルを読み込めませんでした。ファイルが破損しているか、形式が正しくない可能性があります。"
                    case .noPages:
                        errorMsg = "PDFにページがありません。"
                    }
                    self.flowState = .error(errorMsg)
                }
                return
            } catch {
                await MainActor.run {
                    let errorMsg = "PDFの処理中にエラーが発生しました: \(error.localizedDescription)\n\n考えられる原因:\n- ファイルが大きすぎる（22ページ以上）\n- メモリ不足\n- PDFファイルが破損している"
                    self.flowState = .error(errorMsg)
                }
                return
            }
            
            guard !images.isEmpty else {
                await MainActor.run {
                    self.flowState = .error("PDFから画像を生成できませんでした。\n\n考えられる原因:\n- PDFが空または破損している\n- セキュリティで保護されたPDF\n- メモリ不足（ページ数が多すぎる）")
                }
                return
            }
            
            #if DEBUG
            print("[ScannerViewModel] PDF converted to \(images.count) images")
            #endif
            
            // ページ数が分かったので、スキャン状態に切り替え
            await MainActor.run {
                self.flowState = .scanning(page: 0, total: images.count)
            }
            
            await processImagesSequentially(images: images)
        }
    }
    
    /// PDFを画像に変換（非同期、エラーハンドリング付き）
    private func convertPDFToImages(url: URL) async throws -> [UIImage] {
        // PDFドキュメントの読み込み（MainActorで実行）
        let document = await MainActor.run {
            PDFDocument(url: url)
        }
        
        guard let document = document else {
            throw PDFConversionError.failedToLoadDocument
        }
        
        let pageCount = await MainActor.run {
            document.pageCount
        }
        
        guard pageCount > 0 else {
            throw PDFConversionError.noPages
        }
        
        // ページ数が多い場合の警告
        if pageCount > 20 {
            await MainActor.run {
                self.flowState = .analyzing // 一時的にanalyzing状態に
            }
        }
        
        var images: [UIImage] = []
        var failedPages: [Int] = []
        
        // ページごとに処理（メモリ効率を考慮）
        for i in 0..<pageCount {
            // 進捗を更新（10ページ以上の場合）
            if pageCount > 10 && (i == 0 || i % 5 == 0 || i == pageCount - 1) {
                await MainActor.run {
                    // 進捗表示はflowStateで管理
                    if case .analyzing = self.flowState {
                        // 進捗メッセージを更新（可能であれば）
                    }
                }
            }
            
            let page = await MainActor.run {
                document.page(at: i)
            }
            
            guard let page = page else {
                failedPages.append(i + 1)
                continue
            }
            
            let image = await MainActor.run {
                let pageRect = page.bounds(for: .mediaBox)
                
                // 解像度を下げてメモリ使用量を削減（22ページ対応）
                let format = UIGraphicsImageRendererFormat()
                format.scale = 2.0 // 3.0から2.0に下げてメモリ使用量を削減
                
                let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)
                
                return renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(pageRect)
                    ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
            }
            
            images.append(image)
        }
        
        // 失敗したページがある場合の警告
        if !failedPages.isEmpty && images.isEmpty {
            throw PDFConversionError.failedToLoadDocument
        }
        
        return images
    }
    
    private enum PDFConversionError: LocalizedError {
        case failedToLoadDocument
        case noPages
        
        var errorDescription: String? {
            switch self {
            case .failedToLoadDocument:
                return "PDFファイルを読み込めませんでした"
            case .noPages:
                return "PDFにページがありません"
            }
        }
    }
    
    func scanURL(_ urlString: String) {
        // URLの正規化（http/httpsがなければ自動的に追加）
        var normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // スキームがない場合は https:// を追加
        if !normalizedURLString.lowercased().hasPrefix("http://") && !normalizedURLString.lowercased().hasPrefix("https://") {
            normalizedURLString = "https://" + normalizedURLString
        }
        
        guard let url = normalizedURL(from: normalizedURLString) else {
            flowState = .error(L10n.invalidURL.text)
            return
        }
        
        // URLスキャン開始（進捗は不明なのでanalyzing状態にする）
        flowState = .analyzing
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let text = try await webPageHelper.fetchText(from: url)
                if text.isEmpty {
                    self.flowState = .error(L10n.webPageLoadError.text)
                } else {
                    let (limitedText, truncated) = self.clampTextToLimit(text)
                    self.scannedText = limitedText
                    if truncated {
                        let limit = storeKitService.currentPlan.characterLimit
                        let message = LanguageManager.shared.currentLanguage == .japanese
                        ? "読み取ったテキストが上限（\(limit)文字）を超えたため、先頭\(limit)文字のみ保持しました。"
                        : "The fetched text exceeds the limit (\(limit) chars). Kept only the first \(limit) characters."
                        self.flowState = .error(message)
                    } else {
                        self.flowState = .idle
                    }
                }
            } catch {
                let errorMsg = self.errorMessage(from: error)
                self.flowState = .error(errorMsg)
            }
        }
    }
    
    private func processImagesSequentially(images: [UIImage], index: Int = 0, accumulatedText: [String] = []) async {
        // 範囲チェックを先に行う
        if index >= images.count {
            await MainActor.run {
                let fullText = accumulatedText.joined(separator: "\n\n--- Page Break ---\n\n")
                
                if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.flowState = .error(L10n.textRecognitionError.text)
                } else {
                    let (limitedText, truncated) = self.clampTextToLimit(fullText)
                    self.scannedText = limitedText
                    if truncated {
                        let limit = storeKitService.currentPlan.characterLimit
                        let message = LanguageManager.shared.currentLanguage == .japanese
                        ? "読み取ったテキストが上限（\(limit)文字）を超えたため、先頭\(limit)文字のみ保持しました。"
                        : "Scanned text exceeds the limit (\(limit) chars). Kept only the first \(limit) characters."
                        self.flowState = .error(message)
                    } else {
                        self.flowState = .idle
                    }
                    #if DEBUG
                    print("[ScannerViewModel] OCR completed. Total text length: \(fullText.count) characters")
                    #endif
                }
            }
            return
        }
        
        // ページ数を更新（index + 1がtotalを超えないように制限）
        await MainActor.run {
            let currentPage = min(index + 1, images.count)
            self.flowState = .scanning(page: currentPage, total: images.count)
        }
        
        let currentImage = images[index]
        
        #if DEBUG
        print("[ScannerViewModel] Processing page \(index + 1)/\(images.count)")
        #endif
        
        do {
            // OCR処理（タイムアウトを考慮して処理）
            let text = try await withTimeout(seconds: 60) {
                try await self.ocrService.performOCR(on: currentImage)
            }
            
            var nextAccumulatedText = accumulatedText
            nextAccumulatedText.append(text.isEmpty ? "[Page \(index + 1): 空白ページ]" : text)
            await processImagesSequentially(images: images, index: index + 1, accumulatedText: nextAccumulatedText)
        } catch {
            #if DEBUG
            print("[ScannerViewModel] OCR error on page \(index + 1): \(error)")
            #endif
            var nextAccumulatedText = accumulatedText
            let errorMsg = error.localizedDescription
            nextAccumulatedText.append("[Page \(index + 1): 読み取り失敗 - \(errorMsg)]")
            // エラーが発生しても次のページに進む
            await processImagesSequentially(images: images, index: index + 1, accumulatedText: nextAccumulatedText)
        }
    }
    
    /// タイムアウト付きの非同期処理
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // メイン処理
            group.addTask {
                try await operation()
            }
            
            // タイムアウト処理
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // 最初に完了したタスクの結果を返す
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            // 残りのタスクをキャンセル
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: LocalizedError {
        var errorDescription: String? {
            return "OCR処理がタイムアウトしました。ページが大きすぎる可能性があります。"
        }
    }
    
    func analyzeContract() {
        guard !scannedText.isEmpty else { return }
        
        // プランごとの文字数制限をチェック
        if exceedsCharacterLimit(scannedText) {
            activeSheet = .tokenLimitAlert
            return
        }
        
        // 全プランで直接解析（広告機能は後のアップデートで追加）
        performAnalysis()
    }
    
    /// 広告を表示してから解析を実行（無料プラン専用）
    func showAdAndAnalyze() {
        #if DEBUG
        // デバッグ環境: 広告が準備できていない場合は直接解析を実行
        if !adMobManager.isAdReady {
            print("🔧 DEBUG: 広告が準備できていないため、広告をスキップして解析を実行します")
            performAnalysis()
            return
        }
        #else
        // 本番環境: 広告が必須
        guard adMobManager.isAdReady else {
            flowState = .error(L10n.adNotReady.text)
            return
        }
        #endif
        
        // 現在のUIViewControllerを取得
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            flowState = .error(L10n.adLoadingError.text)
            return
        }
        
        // 広告を表示
        adMobManager.showRewardedAd(from: rootViewController) { [weak self] didEarnReward in
            guard let self = self else { return }
            
            if didEarnReward {
                // 広告視聴完了後、解析を実行
                DispatchQueue.main.async {
                    self.performAnalysis()
                }
            } else {
                // 広告視聴失敗
                DispatchQueue.main.async {
                    #if DEBUG
                    // デバッグ環境: 失敗しても解析を実行
                    print("🔧 DEBUG: 広告表示に失敗しましたが、解析を続行します")
                    self.performAnalysis()
                    #else
                    self.flowState = .error(L10n.adLoadingError.text)
                    #endif
                }
            }
        }
    }
    
    func analyzeWithTruncation() {
        let limit = storeKitService.currentPlan.characterLimit
        let truncatedText = String(scannedText.prefix(limit))
        performAnalysis(textOverride: truncatedText)
    }
    
    private func exceedsCharacterLimit(_ text: String) -> Bool {
        text.count > storeKitService.currentPlan.characterLimit
    }
    
    /// 入力テキストを現在プランの上限に合わせて切り詰める
    private func clampTextToLimit(_ text: String) -> (String, Bool) {
        let limit = storeKitService.currentPlan.characterLimit
        guard text.count > limit else { return (text, false) }
        let limited = String(text.prefix(limit))
        return (limited, true)
    }
    
    private func performAnalysis(textOverride: String? = nil) {
        #if !DEBUG
        // 本番環境でのみプランチェック
        if !storeKitService.canScan {
            activeSheet = .paywall
            return
        }
        #endif
        
        flowState = .analyzing
        
        // 進捗タイマーを開始
        startProgressTimer()
        
        let textToAnalyze = textOverride ?? scannedText
        
        // AIモデルの決定ロジック
        // プロプランの制限に達した場合は、スタンダードプランのAIモデルに自動切り替え
        let model: String
        if storeKitService.currentPlan == .pro {
            // プロプランの場合、制限に達しているかチェック
            if storeKitService.currentPlan.dailyLimit != -1 && 
               storeKitService.scanCountToday >= storeKitService.currentPlan.dailyLimit {
                // プロプランの制限に達した場合、スタンダードプランのAIモデル（gpt-4o-mini）を使用
                model = UserPlan.standard.aiModel
            } else {
                // プロプランの制限内の場合、プロプランのAIモデル（gpt-4o）を使用
                model = storeKitService.currentPlan.aiModel
            }
        } else {
            // フリープラン・スタンダードプランの場合、通常のAIモデルを使用
            model = storeKitService.currentPlan.aiModel
        }
        
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let analysis = try await aiService.analyzeContract(text: textToAnalyze, model: model)
                await MainActor.run {
                self.stopProgressTimer()
                    self.flowState = .idle
                    // analysisResultを先に設定してから、activeSheetを設定
                    self.analysisResult = analysis
                    // SwiftUIの状態更新を確実にするため、次のランループでシートを表示
                    Task { @MainActor in
                        // 次のランループまで待機（SwiftUIの状態更新を確実にする）
                        await Task.yield()
                        // analysisResultが設定されていることを再確認してからシートを表示
                        if self.analysisResult != nil {
                            self.activeSheet = .analysisResult
                        }
                    }
                    self.storeKitService.incrementScanCount()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.stopProgressTimer()
                    self.flowState = .idle
                }
            } catch {
                await MainActor.run {
                    self.stopProgressTimer()
                    #if DEBUG
                    print("[ScannerViewModel] ===== Analysis Error =====")
                    print("[ScannerViewModel] Error type: \(type(of: error))")
                    print("[ScannerViewModel] Error: \(error)")
                    if let localizedError = error as? LocalizedError {
                        print("[ScannerViewModel] Error description: \(localizedError.errorDescription ?? "なし")")
                        print("[ScannerViewModel] Error reason: \(localizedError.failureReason ?? "なし")")
                        print("[ScannerViewModel] Error recovery: \(localizedError.recoverySuggestion ?? "なし")")
                    }
                    print("[ScannerViewModel] =========================")
                    #endif
                    
                    // エラーメッセージを生成
                    var errorMsg: String
                    if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
                        errorMsg = description
                    } else {
                        errorMsg = String(format: L10n.analysisErrorWithDescription.text, error.localizedDescription)
                    }
                    
                    self.flowState = .error(errorMsg)
                }
            }
        }
    }
    
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            scanPDF(url: url)
        case .failure(let error):
            flowState = .error(String(format: L10n.fileLoadError.text, error.localizedDescription))
        }
    }
    
    func handleImageSelection(images: [UIImage]) {
        guard !images.isEmpty else { return }
        scanImages(images)
    }
    
    func clearImage() {
        selectedImage = nil
        scannedText = ""
    }
    
    // MARK: - Private Helpers
    
    private func startScanning(totalPages: Int = 0) {
        DispatchQueue.main.async {
            self.flowState = totalPages > 0 ? .scanning(page: 0, total: totalPages) : .idle
        }
    }
    
    private func normalizedURL(from urlString: String) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
    
    
    private func errorMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        
        let description = error.localizedDescription
        if description.contains("NSURLError") || description.contains("network") || description.contains("timed out") {
            return "ネットワークエラー: インターネット接続を確認してください。"
        } else if description.contains("404") {
            return "ページが見つかりませんでした（404エラー）。URLを確認してください。"
        } else if description.contains("403") || description.contains("401") {
            return "ページへのアクセスが拒否されました。認証が必要な可能性があります。"
        } else {
            return "読み込みエラー: \(description)"
        }
    }
}
