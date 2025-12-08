import SwiftUI

// アプリアイコン用のデザインビュー
// プレビュー画面でこのViewを表示し、スクリーンショットを撮ってアイコンとして使えます
struct AppIconView: View {
    var body: some View {
        ZStack {
            // 背景色（暖色系のグラデーション）
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "E07A5F"), Color(hex: "F2CC8F")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // メインのシンボル（虫眼鏡）
            Image(systemName: "magnifyingglass")
                .font(.system(size: 120, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // アクセント（安心感の盾）
            Image(systemName: "shield.check.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "81B29A")) // Sage Green
                .background(Circle().fill(Color.white).frame(width: 60, height: 60))
                .offset(x: 50, y: 50) // 右下に配置
        }
        .frame(width: 1024, height: 1024) // App Store用アイコンサイズ
        .clipShape(RoundedRectangle(cornerRadius: 0)) // 実際のアイコン設定では角丸は自動適用されるので四角でOK
    }
}

struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconView()
            .previewLayout(.fixed(width: 300, height: 300))
    }
}
