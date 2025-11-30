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
    private let revenueCatService = RevenueCatService.shared
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
        isScanning = true
        errorMessage = nil
        
        DispatchQueue.main.async {
            self.totalScanPages = images.count
            self.currentScanPage = 0
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processImagesSequentially(images: images)
        }
    }
    
    func scanPDF(url: URL) {
        isScanning = true
        errorMessage = nil
        
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
        
        guard let url = URL(string: normalizedURLString) else {
            errorMessage = "無効なURLです。正しいURLを入力してください。"
            return
        }
        
        // URLスキームのバリデーション（http/httpsのみ許可）
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            errorMessage = "http:// または https:// で始まるURLを入力してください。"
            return
        }
        
        isScanning = true
        errorMessage = nil
        currentScanPage = 0
        totalScanPages = 0
        
        webPageHelper.fetchText(from: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.isScanning = false
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        self?.errorMessage = "ページからテキストを読み取れませんでした。ページが空か、アクセスできない可能性があります。"
                    } else {
                        self?.scannedText = text
                    }
                case .failure(let error):
                    // LocalizedErrorプロトコルに準拠している場合はerrorDescriptionを使用
                    if let localizedError = error as? LocalizedError,
                       let description = localizedError.errorDescription {
                        self?.errorMessage = description
                    } else {
                        let errorDesc = error.localizedDescription
                        if errorDesc.contains("NSURLError") || errorDesc.contains("network") || errorDesc.contains("timed out") {
                            self?.errorMessage = "ネットワークエラー: インターネット接続を確認してください。"
                        } else if errorDesc.contains("404") {
                            self?.errorMessage = "ページが見つかりませんでした（404エラー）。URLを確認してください。"
                        } else if errorDesc.contains("403") || errorDesc.contains("401") {
                            self?.errorMessage = "ページへのアクセスが拒否されました。認証が必要な可能性があります。"
                        } else {
                            self?.errorMessage = "読み込みエラー: \(errorDesc)"
                        }
                    }
                }
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
        let limit = revenueCatService.currentPlan.characterLimit
        if scannedText.count > limit {
            showingTokenLimitAlert = true
            return
        }
        
        performAnalysis()
    }
    
    func analyzeWithTruncation() {
        let limit = revenueCatService.currentPlan.characterLimit
        let truncatedText = String(scannedText.prefix(limit))
        performAnalysis(textOverride: truncatedText)
    }
    
    private func performAnalysis(textOverride: String? = nil) {
        if !revenueCatService.canScan {
            showingPaywall = true
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        
        let textToAnalyze = textOverride ?? scannedText
        
        // AIモデルの決定ロジック（全プランでgpt-4o-miniを使用）
        let model = revenueCatService.currentPlan.aiModel
        
        openAIService.analyzeContract(text: textToAnalyze, model: model) { [weak self] (result: Result<AnalysisResult, Error>) in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                switch result {
                case .success(let analysis):
                    self?.analysisResult = analysis
                    self?.showingAnalysisResult = true
                    self?.revenueCatService.incrementScanCount()
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
}
