import Foundation
import Combine
import SwiftUI
import Vision
import VisionKit
import AVFoundation

class ScannerViewModel: ObservableObject {
    @Published var scannedText = ""
    @Published var isScanning = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var analysisResult: AnalysisResult?
    
    // 進捗表示用
    @Published var currentScanPage: Int = 0
    @Published var totalScanPages: Int = 0
    
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
    
    func checkCameraPermission() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            print("ERROR: NSCameraUsageDescription not found in Info.plist")
            self.errorMessage = "カメラの使用許可設定が不足しています。開発者にお問い合わせください。"
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
                    self?.errorMessage = "PDFを読み込めませんでした"
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
            errorMessage = "http:// または https:// で始まる正しいURLを入力してください。"
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
                    self.errorMessage = "文字を読み取れませんでした"
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
        
        performAnalysis()
    }
    
    func analyzeWithTruncation() {
        let limit = storeKitService.currentPlan.characterLimit
        let truncatedText = String(scannedText.prefix(limit))
        performAnalysis(textOverride: truncatedText)
    }
    
    private func performAnalysis(textOverride: String? = nil) {
        if !storeKitService.canScan {
            showingPaywall = true
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        
        let textToAnalyze = textOverride ?? scannedText
        
        // AIモデルの決定ロジック（全プランでgpt-4o-miniを使用）
        let model = storeKitService.currentPlan.aiModel
        
        openAIService.analyzeContract(text: textToAnalyze, model: model) { [weak self] (result: Result<AnalysisResult, Error>) in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                switch result {
                case .success(let analysis):
                    self?.analysisResult = analysis
                    self?.showingAnalysisResult = true
                    self?.storeKitService.incrementScanCount()
                case .failure(let error):
                    self?.errorMessage = "解析エラー: \(error.localizedDescription)"
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
            errorMessage = "ファイル読み込みエラー: \(error.localizedDescription)"
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
                errorMessage = "ページからテキストを読み取れませんでした。ページが空か、アクセスできない可能性があります。"
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
