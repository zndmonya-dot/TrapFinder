import SwiftUI
import UIKit
import Vision
import VisionKit
import PhotosUI

struct DocumentCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        
        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scan failed: \(error.localizedDescription)")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @EnvironmentObject var storeKitService: StoreKitService
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var adMobManager: AdMobManager
    
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScannerContentView(
                viewModel: viewModel,
                showingSettings: $showingSettings
            )
            .navigationBarHidden(true)
            .onChange(of: viewModel.selectedImage) { _, newImage in
                if let image = newImage {
                    viewModel.scanImage(image)
                }
            }
            .sheet(item: $viewModel.activeSheet) { sheet in
                switch sheet {
                case .analysisResult:
                    // analysisResultがnilの場合はシートを表示しない
                if let result = viewModel.analysisResult {
                    AnalysisResultView(result: result)
                    } else {
                        // analysisResultがnilの場合は何も表示しない（シートは自動的に閉じる）
                        EmptyView()
                }
                case .imagePicker:
                ImagePicker(onImagesPicked: { images in
                    viewModel.handleImageSelection(images: images)
                })
                case .textInput:
                    TextInputView(text: $viewModel.scannedText, characterLimit: storeKitService.currentPlan.characterLimit)
                case .urlInput:
                    URLInputView(viewModel: viewModel)
                case .paywall:
                    PaywallView()
                case .cameraAlert, .tokenLimitAlert:
                    // これらは.alertで表示されるため、.sheetでは何も表示しない
                    EmptyView()
                }
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                CameraView(image: $viewModel.selectedImage)
            }
            .fileImporter(
                isPresented: $viewModel.showingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result: result)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert(item: Binding<AlertItem?>(
                get: {
                    if case .error(let message) = viewModel.flowState {
                        return AlertItem(message: message)
                    }
                    return nil
                },
                set: { _ in
                    if case .error = viewModel.flowState {
                        viewModel.flowState = .idle
                    }
                }
            )) { item in
                Alert(title: Text(L10n.error.text), message: Text(item.message), dismissButton: .default(Text("OK")))
            }
            .alert(item: Binding<ActiveSheet?>(
                get: { viewModel.activeSheet == .cameraAlert ? .cameraAlert : nil },
                set: { _ in viewModel.activeSheet = nil }
            )) { _ in
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
            .alert(item: Binding<ActiveSheet?>(
                get: { viewModel.activeSheet == .tokenLimitAlert ? .tokenLimitAlert : nil },
                set: { _ in viewModel.activeSheet = nil }
            )) { _ in
                let characterLimit = storeKitService.currentPlan.characterLimit
                let formattedLimit = characterLimit >= 10000 
                    ? String(format: "%.0f万", Double(characterLimit) / 10000.0)
                    : String(format: "%d", characterLimit)
                let messageText = languageManager.currentLanguage == .japanese
                    ? "読み取った文字数が\(formattedLimit)文字を超えています。\nすべて解析すると時間がかかり、エラーになる可能性があります。\n\n先頭の\(formattedLimit)文字だけ解析しますか？"
                    : "The scanned text exceeds \(characterLimit) characters.\nAnalyzing all of it may take time and could cause errors.\n\nWould you like to analyze only the first \(characterLimit) characters?"
                
                return Alert(
                    title: Text(L10n.tokenLimitTitle.text),
                    message: Text(messageText),
                    primaryButton: .default(Text(L10n.analyzeTruncated.text)) {
                        viewModel.analyzeWithTruncation()
                    },
                    secondaryButton: .cancel(Text(L10n.cancel.text))
                )
            }
        }
        .accentColor(Color(hex: "E07A5F"))
        // 言語変更時は@ObservedObjectが自動的にUIを更新するため、.id()は不要
    }
}

// MARK: - Subviews

struct ScannerContentView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @EnvironmentObject var storeKitService: StoreKitService
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var adMobManager: AdMobManager
    @Binding var showingSettings: Bool
    
    let bgGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "FFF8F0"), Color(hex: "FDE4CF")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private var scannerActions: [ScannerAction] {
        [
            ScannerAction(
                title: L10n.cameraScan.text,
                subtitle: L10n.cameraScanDesc.text,
                icon: "camera.fill",
                tintColor: Color(hex: "E07A5F"),
                handler: { viewModel.checkCameraPermission() }
            ),
            ScannerAction(
                title: L10n.albumSelect.text,
                subtitle: L10n.albumSelectDesc.text,
                icon: "photo.on.rectangle.fill",
                tintColor: Color(hex: "F2CC8F"),
                handler: { viewModel.activeSheet = .imagePicker }
            ),
            ScannerAction(
                title: L10n.pdfImport.text,
                subtitle: L10n.pdfImportDesc.text,
                icon: "doc.text.fill",
                tintColor: Color(hex: "81B29A"),
                handler: { viewModel.showingFileImporter = true }
            ),
            ScannerAction(
                title: L10n.webPage.text,
                subtitle: L10n.webPageDesc.text,
                icon: "globe",
                tintColor: Color(hex: "3D405B"),
                handler: { viewModel.activeSheet = .urlInput }
            ),
            ScannerAction(
                title: L10n.textInput.text,
                subtitle: L10n.textInputDesc.text,
                icon: "keyboard",
                tintColor: Color(hex: "9D8189"),
                handler: { viewModel.activeSheet = .textInput }
            )
        ]
    }
    
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
                            
                            // 使い方ガイドカード（ポップなデザイン）
                            HowToUseCard()
                            
                            ForEach(scannerActions) { action in
                                ListButton(
                                    title: action.title,
                                    subtitle: action.subtitle,
                                    icon: action.icon,
                                    color: action.tintColor,
                                    action: action.handler
                                )
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
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
                                Image(systemName: storeKitService.currentPlan == .free ? "play.rectangle.fill" : "sparkles")
                                Text(storeKitService.currentPlan == .free ? L10n.watchAdToAnalyze.text : L10n.analyzeButton.text)
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
            
            if let message = overlayMessage {
                LoadingOverlay(message: message)
            }
        }
    }
    
    private var overlayMessage: String? {
        switch viewModel.flowState {
        case .scanning(let page, let total):
            if total > 1 {
                return "\(L10n.scanning.text)\n(\(page)/\(total))"
            } else {
                return L10n.scanning.text
            }
        case .analyzing:
            return L10n.analyzing.text
        default:
            return nil
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

private struct ScannerAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tintColor: Color
    let handler: () -> Void
}

// 使い方ガイドカード
struct HowToUseCard: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー部分（常に表示）
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "E07A5F"), Color(hex: "F2CC8F")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.howToUseTitle.text)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B"))
                        
                        Text(isExpanded ? L10n.howToUseTapToClose.text : L10n.howToUseTapToOpen.text)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "E07A5F"))
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(16)
            }
            
            // 展開部分
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    // ステップ1
                    HowToUseStep(
                        number: "1",
                        title: L10n.howToUseStep1.text,
                        description: L10n.howToUseStep1Desc.text,
                        icon: "doc.text.magnifyingglass",
                        color: Color(hex: "E07A5F")
                    )
                    
                    // ステップ2
                    HowToUseStep(
                        number: "2",
                        title: L10n.howToUseStep2.text,
                        description: L10n.howToUseStep2Desc.text,
                        icon: "sparkles",
                        color: Color(hex: "F2CC8F")
                    )
                    
                    // ステップ3
                    HowToUseStep(
                        number: "3",
                        title: L10n.howToUseStep3.text,
                        description: L10n.howToUseStep3Desc.text,
                        icon: "checkmark.seal.fill",
                        color: Color(hex: "81B29A")
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity) // シンプルなフェードインに戻す
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: "E07A5F").opacity(0.15), radius: 10, x: 0, y: 5)
        // .clipped() // 削除
    }
}

// 使い方ステップコンポーネント
struct HowToUseStep: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // 番号バッジ
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Text(number)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            // アイコン
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            // テキスト
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
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
                
                TextField("https://", text: $urlString)
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
                
                Text(L10n.webPageInputHint.text)
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
                    Button(L10n.load.text) {
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
    let characterLimit: Int
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var languageManager: LanguageManager
    
    private var limitText: String {
        let formattedLimit = characterLimit >= 10000 
            ? String(format: "%.0f万", Double(characterLimit) / 10000.0)
            : String(format: "%d", characterLimit)
        return languageManager.currentLanguage == .japanese
            ? "※\(formattedLimit)文字まで入力可能です"
            : "※Up to \(characterLimit) characters can be entered"
    }
    
    private var counterText: String {
        "\(text.count)/\(characterLimit)"
    }
    
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
                    .onChange(of: text) { _, newValue in
                        if newValue.count > characterLimit {
                            text = String(newValue.prefix(characterLimit))
                        }
                    }
                
                Text(limitText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                
                Text(counterText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
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
                    Button(L10n.done.text) {
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
