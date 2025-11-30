import SwiftUI
import UIKit
import Vision
import VisionKit
import PhotosUI

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @StateObject private var revenueCatService = RevenueCatService.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScannerContentView(
                viewModel: viewModel,
                revenueCatService: revenueCatService, // 引数追加
                showingSettings: $showingSettings
            )
            .navigationBarHidden(true)
            .onChange(of: viewModel.selectedImage) { _, newImage in
                if let image = newImage {
                    viewModel.scanImage(image)
                }
            }
            .sheet(isPresented: $viewModel.showingAnalysisResult) {
                if let result = viewModel.analysisResult {
                    AnalysisResultView(result: result)
                }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePicker(onImagesPicked: { images in
                    viewModel.handleImageSelection(images: images)
                })
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                CameraView(image: $viewModel.selectedImage)
            }
            .sheet(isPresented: $viewModel.showingTextInput) {
                TextInputView(text: $viewModel.scannedText)
            }
            .sheet(isPresented: $viewModel.showingURLInput) {
                URLInputView(viewModel: viewModel)
            }
            .fileImporter(
                isPresented: $viewModel.showingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result: result)
            }
            .sheet(isPresented: $viewModel.showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert(item: Binding<AlertItem?>(
                get: { viewModel.errorMessage.map { AlertItem(message: $0) } },
                set: { _ in viewModel.errorMessage = nil }
            )) { item in
                Alert(title: Text(L10n.error.text), message: Text(item.message), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $viewModel.showingCameraAlert) {
                Alert(
                    title: Text(L10n.cameraPermissionTitle.text),
                    message: Text(L10n.cameraPermissionMsg.text),
                    primaryButton: .default(Text(L10n.openSettings.text)) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text(L10n.cancel.text))
                )
            }
            .alert(isPresented: $viewModel.showingTokenLimitAlert) {
                Alert(
                    title: Text("文字数が多すぎます"), // ここもローカライズ必要だが今回はスキップ
                    message: Text("読み取った文字数が20,000文字を超えています。\nすべて解析すると時間がかかり、エラーになる可能性があります。\n\n先頭の20,000文字だけ解析しますか？"),
                    primaryButton: .default(Text("先頭のみ解析する")) {
                        viewModel.analyzeWithTruncation()
                    },
                    secondaryButton: .cancel(Text(L10n.cancel.text))
                )
            }
        }
        .accentColor(Color(hex: "E07A5F"))
        .id(languageManager.currentLanguage.id) // 言語切り替え対応
    }
}

// MARK: - Subviews

struct ScannerContentView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @ObservedObject var revenueCatService = RevenueCatService.shared // プロパティ追加
    @Binding var showingSettings: Bool
    
    let bgGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "FFF8F0"), Color(hex: "FDE4CF")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー部分
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "E07A5F"))
                        Text("TrapFinder")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B"))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                            .padding(8)
                            .background(Color.white.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        if viewModel.scannedText.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) { // 均等な間隔で並べる
                            Spacer(minLength: 10)
                            
                            // 全ての機能を横長カード（リスト形式）で統一
                            // L10nを使って多言語対応
                            
                            ListButton(
                                title: L10n.cameraScan.text,
                                subtitle: L10n.cameraScanDesc.text,
                                icon: "camera.fill",
                                color: Color(hex: "E07A5F")
                            ) {
                                viewModel.checkCameraPermission()
                            }
                            
                            ListButton(
                                title: L10n.albumSelect.text,
                                subtitle: L10n.albumSelectDesc.text,
                                icon: "photo.on.rectangle.fill",
                                color: Color(hex: "F2CC8F")
                            ) {
                                viewModel.showingImagePicker = true
                            }
                            
                            ListButton(
                                title: L10n.pdfImport.text,
                                subtitle: L10n.pdfImportDesc.text,
                                icon: "doc.text.fill",
                                color: Color(hex: "81B29A")
                            ) {
                                viewModel.showingFileImporter = true
                            }
                            
                            ListButton(
                                title: L10n.webPage.text,
                                subtitle: L10n.webPageDesc.text,
                                icon: "globe",
                                color: Color(hex: "3D405B")
                            ) {
                                viewModel.showingURLInput = true
                            }
                            
                            ListButton(
                                title: L10n.textInput.text,
                                subtitle: L10n.textInputDesc.text,
                                icon: "keyboard",
                                color: Color(hex: "9D8189")
                            ) {
                                viewModel.showingTextInput = true
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "shield.check.fill")
                                    .foregroundColor(Color(hex: "81B29A"))
                                Text(L10n.dataPrivacy.text)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                            }
                            .padding(.top, 10)
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    }
                } else {
                    // 読み取り完了画面
                    VStack(spacing: 20) {
                        HStack {
                            Text(L10n.readComplete.text)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B"))
                            Spacer()
                            Button(action: { viewModel.clearImage() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        
                        TextEditor(text: $viewModel.scannedText)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B"))
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 24)
                        
                        Button {
                            viewModel.analyzeContract()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text(L10n.analyzeButton.text)
                                    .fontWeight(.bold)
                            }
                            .font(.system(.title3, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(hex: "E07A5F"))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .shadow(color: Color(hex: "E07A5F").opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                }
            }
            
            if viewModel.isScanning || viewModel.isAnalyzing {
                let message: String = {
                    if viewModel.isScanning {
                        if viewModel.totalScanPages > 1 {
                            return "\(L10n.scanning.text)\n(\(viewModel.currentScanPage)/\(viewModel.totalScanPages))"
                        } else {
                            return L10n.scanning.text
                        }
                    } else {
                        return L10n.analyzing.text
                    }
                }()
                LoadingOverlay(message: message)
            }
        }
    }
}

// 新しいリスト形式のボタンコンポーネント
struct ListButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // アイコン部分
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                // テキスト部分
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // 矢印
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(color)
            .cornerRadius(20)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// 既存の補助ビューは変更なし（省略せず記述）
struct URLInputView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var urlString = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(L10n.webPageDesc.text) // ローカライズ
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                    .padding(.top)
                
                TextField("https://example.com/terms", text: $urlString)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Text("利用規約やプライバシーポリシーのページURLを入力してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(hex: "FFF8F0").ignoresSafeArea())
            .navigationTitle(L10n.webPage.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel.text) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("読み込む") {
                        viewModel.scanURL(urlString)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "E07A5F"))
                    .disabled(urlString.isEmpty)
                }
            }
        }
    }
}

struct TextInputView: View {
    @Binding var text: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.textInputDesc.text) // ローカライズ
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                    .padding(.horizontal)
                    .padding(.top)
                
                TextEditor(text: $text)
                    .font(.system(.body, design: .rounded))
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                    .padding(.horizontal)
                
                Text("※20,000文字まで入力可能です")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .background(Color(hex: "FFF8F0").ignoresSafeArea())
            .navigationTitle(L10n.textInput.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel.text) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "E07A5F"))
                }
            }
        }
    }
}

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "E07A5F")))
                
                Text(message)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                    .multilineTextAlignment(.center)
            }
        }
        .zIndex(1)
    }
}

struct AlertItem: Identifiable {
    var id = UUID()
    var message: String
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var onImagesPicked: ([UIImage]) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard !results.isEmpty else { return }
            
            let group = DispatchGroup()
            var imagesDict = [Int: UIImage]()
            
            for (index, result) in results.enumerated() {
                group.enter()
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, error in
                        defer { group.leave() }
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                imagesDict[index] = image
                            }
                        }
                    }
                } else {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                let sortedImages = imagesDict.sorted { $0.key < $1.key }.map { $0.value }
                self.parent.onImagesPicked(sortedImages)
            }
        }
    }
}
