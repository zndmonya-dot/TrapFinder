import SwiftUI

struct LegalDisclaimerView: View {
    @Binding var hasAgreed: Bool
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill") // アイコン変更
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "E07A5F")) // テーマカラー
                        .padding(.top, 40)
                    
                    Text(L10n.legalTitle.text)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "3D405B"))
                        .multilineTextAlignment(.center)
                }
                
                // コンテンツ
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        DisclaimerItem(
                            title: L10n.legalHeader1.text,
                            content: L10n.legalText1.text,
                            icon: "doc.text.magnifyingglass"
                        )
                        
                        DisclaimerItem(
                            title: L10n.legalHeader2.text,
                            content: L10n.legalText2.text,
                            icon: "person.fill.checkmark"
                        )
                        
                        DisclaimerItem(
                            title: L10n.legalHeader3.text,
                            content: L10n.legalText3.text,
                            icon: "gavel.fill"
                        )
                        
                        DisclaimerItem(
                            title: L10n.legalHeader4.text,
                            content: L10n.legalText4.text,
                            icon: "lock.fill"
                        )
                        
                        DisclaimerItem(
                            title: L10n.legalHeader5.text,
                            content: L10n.legalText5.text,
                            icon: "doc.text.fill"
                        )
                    }
                    .padding(24)
                }
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color(hex: "E07A5F").opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                
                // 同意ボタン
                Button(action: {
                    hasAgreed = true
                }) {
                    Text(L10n.agreeButton.text)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "E07A5F"))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "E07A5F").opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

struct DisclaimerItem: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "E07A5F"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                
                Text(content)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B").opacity(0.8))
                    .lineSpacing(4)
            }
        }
    }
}
