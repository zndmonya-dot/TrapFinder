import SwiftUI

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        // NavigationViewで囲むことで、ScannerViewと同じレイアウト環境（SafeAreaの扱い）にする
        NavigationView {
            ZStack(alignment: .top) {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "FFF8F0"), Color(hex: "FDE4CF")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 中央にロゴを表示（アニメーション付き）
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "E07A5F"))
                        
                        Text("TrapFinder")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B"))
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true) // ナビゲーションバーは隠す
        }
        .onAppear {
            // ロゴのフェードイン・スケールアニメーション
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
