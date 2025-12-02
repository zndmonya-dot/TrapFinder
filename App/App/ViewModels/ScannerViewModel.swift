import Foundation
import Combine
import SwiftUI
import Vision
import VisionKit
import AVFoundation
import GoogleMobileAds

class ScannerViewModel: ObservableObject {
    @Published var scannedText = ""
    @Published var isScanning = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var analysisResult: AnalysisResult?
    
    // 進捗表示用
    @Published var currentScanPage: Int = 0
    @Published var totalScanPages: Int = 0
    @Published var analysisProgressMessage: String = ""
    
    // UI State Flags
    @Published var showingCamera = false
    @Published var showingImagePicker = false
    @Published var showingFileImporter = false
    @Published var showingTextInput = false
    @Published var showingURLInput = false
    @Published var showingAnalysisResult = false
    @Published var showingPaywall = false
    @Published var showingCameraAlert = false
    @Published var showingReSelectionAlert = false
    
    @Published var showingTokenLimitAlert = false
    
    @Published var selectedImage: UIImage?
    
    private var cancellables = Set<AnyCancellable>()
    private let ocrService = OCRService.shared
    private let openAIService = OpenAIService.shared
    private let storeKitService = StoreKitService.shared
    private let webPageHelper = WebPageHelper.shared
    
    // 進捗表示用のタイマー
    private var progressTimer: Timer?
    
    /// 解析をキャンセル
    func cancelAnalysis() {
        openAIService.cancelCurrentRequest()
        webPageHelper.cancelCurrentRequest()
        isAnalyzing = false
        isScanning = false
        stopProgressTimer()
    }
    
    /// 進捗タイマーを開始
    private func startProgressTimer() {
        stopProgressTimer()
        analysisProgressMessage = L10n.analyzing.text
        
        var elapsedSeconds = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isAnalyzing else {
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
            self.errorMessage = L10n.cameraPermissionMissing.text
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
                        self.showingCameraAlert = true
                    }
                }
            }
        case .denied, .restricted:
            self.showingCameraAlert = true
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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processImagesSequentially(images: images)
        }
    }
    
    func scanPDF(url: URL) {
        startScanning()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let images = PDFHelper.pdfToImages(url: url)
            
            DispatchQueue.main.async {
                self?.totalScanPages = images.count
                self?.currentScanPage = 0
            }
            
            guard !images.isEmpty else {
                DispatchQueue.main.async {
                    self?.isScanning = false
                    self?.errorMessage = L10n.pdfLoadError.text
                }
                return
            }
            
            self?.processImagesSequentially(images: images)
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
            errorMessage = L10n.invalidURL.text
            return
        }
        
        startScanning()
        webPageHelper.fetchText(from: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleWebTextFetch(result)
            }
        }
    }
    
    private func processImagesSequentially(images: [UIImage], index: Int = 0, accumulatedText: [String] = []) {
        DispatchQueue.main.async {
            self.currentScanPage = index + 1
        }
        
        if index >= images.count {
            DispatchQueue.main.async {
                self.isScanning = false
                let fullText = accumulatedText.joined(separator: "\n\n--- Page Break ---\n\n")
                
                if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.errorMessage = L10n.textRecognitionError.text
                } else {
                    self.scannedText = fullText
                }
            }
            return
        }
        
        let currentImage = images[index]
        
        ocrService.performOCR(on: currentImage) { [weak self] result in
            var nextAccumulatedText = accumulatedText
            
            switch result {
            case .success(let text):
                nextAccumulatedText.append(text.isEmpty ? "[Page \(index + 1): 空白ページ]" : text)
            case .failure(let error):
                nextAccumulatedText.append("[Page \(index + 1): 読み取り失敗 - \(error.localizedDescription)]")
            }
            
            self?.processImagesSequentially(images: images, index: index + 1, accumulatedText: nextAccumulatedText)
        }
    }
    
    func analyzeContract() {
        guard !scannedText.isEmpty else { return }
        
        // プランごとの文字数制限をチェック
        let limit = storeKitService.currentPlan.characterLimit
        if scannedText.count > limit {
            showingTokenLimitAlert = true
            return
        }
        
        // フリープランの場合のみ、動画広告を表示してから解析を開始
        // スタンダードプランとプロプランは広告非表示で直接解析を開始
        if storeKitService.currentPlan == .free {
            showAdBeforeAnalysis()
        } else {
            // スタンダードプラン・プロプランは広告なしで直接解析を開始
            performAnalysis()
        }
    }
    
    /// 動画広告を表示してから解析を開始（フリープランのみ）
    private func showAdBeforeAnalysis() {
        Task { @MainActor in
            let adMobService = AdMobService.shared
            
            // リワード広告を読み込んで表示、最後まで見たら解析を開始
            adMobService.loadRewardedAd { [weak self] watched in
                guard let self = self else { return }
                
                if watched {
                    // 広告を最後まで見た場合のみ、解析を開始
                    self.performAnalysis()
                } else {
                    // 広告を見なかった、または読み込みに失敗した場合は、エラーメッセージを表示
                    let currentLanguage = LanguageManager.shared.currentLanguage
                    self.errorMessage = currentLanguage == .japanese
                        ? "動画広告を最後まで視聴すると、AI解析を利用できます。"
                        : "Please watch the video ad to the end to use AI analysis."
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    func analyzeWithTruncation() {
        let limit = storeKitService.currentPlan.characterLimit
        let truncatedText = String(scannedText.prefix(limit))
        performAnalysis(textOverride: truncatedText)
    }
    
    private func performAnalysis(textOverride: String? = nil) {
        #if !DEBUG
        // 本番環境でのみプランチェック
        if !storeKitService.canScan {
            showingPaywall = true
            return
        }
        #endif
        
        isAnalyzing = true
        errorMessage = nil
        
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
        
        openAIService.analyzeContract(text: textToAnalyze, model: model) { [weak self] (result: Result<AnalysisResult, Error>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 進捗タイマーを停止
                self.stopProgressTimer()
                
                // 解析完了を確実に処理
                self.isAnalyzing = false
                
                switch result {
                case .success(let analysis):
                    // 解析結果を設定してからシートを表示
                    self.analysisResult = analysis
                    // 少し遅延を入れてシートが確実に表示されるようにする
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.showingAnalysisResult = true
                    }
                    self.storeKitService.incrementScanCount()
                case .failure(let error):
                    let errorMsg = String(format: L10n.analysisErrorWithDescription.text, error.localizedDescription)
                    self.errorMessage = errorMsg
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
            errorMessage = String(format: L10n.fileLoadError.text, error.localizedDescription)
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
            self.isScanning = true
            self.errorMessage = nil
            self.totalScanPages = totalPages
            self.currentScanPage = totalPages > 0 ? 0 : self.currentScanPage
        }
    }
    
    private func normalizedURL(from urlString: String) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
    
    private func handleWebTextFetch(_ result: Result<String, Error>) {
        isScanning = false
        switch result {
        case .success(let text):
            if text.isEmpty {
                errorMessage = L10n.webPageLoadError.text
            } else {
                scannedText = text
            }
        case .failure(let error):
            errorMessage = errorMessage(from: error)
        }
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
