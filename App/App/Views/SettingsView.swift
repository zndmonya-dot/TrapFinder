import SwiftUI

struct SettingsView: View {
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingPaywall = false
    @Environment(\.presentationMode) var presentationMode
    
    // トップ画面と同じ背景グラデーション
    let bgGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "FFF8F0"), Color(hex: "FDE4CF")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                bgGradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // プラン情報カード
                        PlanInfoCard(
                            plan: revenueCatService.currentPlan,
                            remainingScans: revenueCatService.remainingFreeScans,
                            onTap: {
                                showingPaywall = true
                            }
                        )
                        
                        // 一般設定セクション
                        VStack(alignment: .leading, spacing: 12) {
                            Text("一般")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                .padding(.horizontal, 4)
                            
                            NavigationLink {
                                LanguageSettingsView()
                            } label: {
                                SettingsRow(icon: "globe", title: L10n.language.text, value: languageManager.currentLanguage.displayName)
                            }
                        }
                        
                        // プラン管理セクション
                        VStack(alignment: .leading, spacing: 12) {
                            Text("プラン管理")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                .padding(.horizontal, 4)
                            
                            // プラン変更画面への導線
                            Button {
                                showingPaywall = true
                            } label: {
                                SettingsRow(icon: "sparkles", title: L10n.upgradeToPro.text, iconColor: .orange)
                            }
                            
                            Button {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                SettingsRow(icon: "creditcard", title: "サブスクリプションの管理")
                            }
                            
                            Button {
                                revenueCatService.restorePurchases { _ in }
                            } label: {
                                SettingsRow(icon: "arrow.clockwise", title: L10n.restorePurchase.text)
                            }
                        }
                        
                        // サポートセクション
                        VStack(alignment: .leading, spacing: 12) {
                            Text("サポート")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                .padding(.horizontal, 4)
                            
                            NavigationLink {
                                Text("利用規約") // 本来はWebViewなど
                                    .navigationTitle(L10n.terms.text)
                            } label: {
                                SettingsRow(icon: "doc.text", title: L10n.terms.text)
                            }
                            
                            NavigationLink {
                                Text("プライバシーポリシー")
                                    .navigationTitle(L10n.privacy.text)
                            } label: {
                                SettingsRow(icon: "hand.raised", title: L10n.privacy.text)
                            }
                        }
                        
                        // アプリ情報セクション
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.appInfo.text)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text(L10n.version.text)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B"))
                                    Spacer()
                                    Text("1.0.0")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                                }
                                .padding()
                                Divider()
                                HStack {
                                    Text(L10n.developer.text)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B"))
                                    Spacer()
                                    Text("Contract Companion Team")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                                }
                                .padding()
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.settings.text)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color(hex: "3D405B"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.3))
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
        // 言語変更時に強制再描画するためのID
        .id(languageManager.currentLanguage.id)
    }
}

struct PlanInfoCard: View {
    let plan: UserPlan
    let remainingScans: Int
    var onTap: () -> Void
    
    var planColor: Color {
        switch plan {
        case .free: return Color(hex: "81B29A") // Sage Green
        case .standard: return Color(hex: "E07A5F") // Terracotta
        }
    }
    
    var planIcon: String {
        switch plan {
        case .free: return "leaf.fill"
        case .standard: return "star.circle.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(planColor)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: planIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "3D405B"))
                    
                    if plan == .free {
                        Text("残り \(remainingScans) 回")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(remainingScans > 0 ? Color(hex: "3D405B").opacity(0.7) : Color.red)
                    } else {
                        Text("スキャン回数無制限")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "3D405B").opacity(0.3))
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: planColor.opacity(0.15), radius: 10, x: 0, y: 5)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var iconColor: Color = Color(hex: "E07A5F")
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color(hex: "3D405B"))
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B").opacity(0.6))
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(hex: "3D405B").opacity(0.3))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct LanguageSettingsView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // 言語設定画面も背景統一
    let bgGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "FFF8F0"), Color(hex: "FDE4CF")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Language.allCases) { language in
                        Button {
                            languageManager.currentLanguage = language
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(Color(hex: "3D405B"))
                                Spacer()
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "E07A5F"))
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.language.text)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
            }
        }
    }
}
