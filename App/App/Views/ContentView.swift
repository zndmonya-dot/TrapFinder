import SwiftUI

struct ContentView: View {
    @AppStorage("hasAgreedToTerms") private var hasAgreedToTerms = false
    @ObservedObject private var languageManager = LanguageManager.shared
    
    // スプラッシュ画面の表示状態
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity) // フェードアウトで消える
                    .zIndex(1) // 最前面に表示
            }
            
            if !showSplash {
                Group {
                    if hasAgreedToTerms {
                        ScannerView()
                    } else {
                        LegalDisclaimerView(hasAgreed: $hasAgreedToTerms)
                    }
                }
                .id(languageManager.currentLanguage.id)
                .transition(.opacity) // フェードインで現れる
            }
        }
        .onAppear {
            // 1秒後にスプラッシュ画面を非表示にする
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }
}
