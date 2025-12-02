import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storeKitService: StoreKitService
    @EnvironmentObject var languageManager: LanguageManager
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
                        // サブスクリプションセクション
                        SettingsSection(title: L10n.planManagement.text) {
                            Button {
                                showingPaywall = true
                            } label: {
                                SettingsRow(
                                    icon: "creditcard.fill",
                                    title: L10n.planManagement.text,
                                    value: storeKitService.currentPlan == .standard ? L10n.standardPlan.text : L10n.freePlan.text,
                                    iconColor: Color(hex: "2A9D8F"), // エメラルドグリーン
                                    showDivider: false
                                )
                            }
                        }
                        
                        // 一般設定セクション
                        SettingsSection(title: L10n.general.text) {
                            NavigationLink {
                                LanguageSettingsView()
                            } label: {
                                SettingsRow(
                                    icon: "globe",
                                    title: L10n.language.text,
                                    value: languageManager.currentLanguage.displayName,
                                    iconColor: Color(hex: "457B9D"), // ブルー
                                    showDivider: false
                                )
                            }
                        }
                        
                        // サポートセクション
                        SettingsSection(title: L10n.support.text) {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    TermsView()
                                        .navigationTitle(L10n.terms.text)
                                } label: {
                                    SettingsRow(
                                        icon: "doc.text.fill",
                                        title: L10n.terms.text,
                                        iconColor: Color(hex: "E07A5F"), // テラコッタ
                                        showDivider: true
                                    )
                                }
                                
                                NavigationLink {
                                    PrivacyPolicyView()
                                        .navigationTitle(L10n.privacy.text)
                                } label: {
                                    SettingsRow(
                                        icon: "hand.raised.fill",
                                        title: L10n.privacy.text,
                                        iconColor: Color(hex: "E07A5F"),
                                        showDivider: false
                                    )
                                }
                            }
                        }
                        
                        // アプリ情報セクション
                        SettingsSection(title: L10n.appInfo.text) {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "info.circle.fill",
                                    title: L10n.version.text,
                                    value: "1.0.0",
                                    iconColor: Color(hex: "3D405B"), // ダークブルー
                                    showChevron: false,
                                    showDivider: true
                                )
                                
                                SettingsRow(
                                    icon: "person.2.fill",
                                    title: L10n.developer.text,
                                    value: "Contract Companion Team",
                                    iconColor: Color(hex: "3D405B"),
                                    showChevron: false,
                                    showDivider: false
                                )
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 24) // 全体のpaddingを変更
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
        // 言語変更時にテキストを更新するため、NavigationViewの外でIDを設定
        .onChange(of: languageManager.currentLanguage) { _, _ in
            // 言語変更時は自動的にUIが更新されるため、特別な処理は不要
        }
    }
}

// PlanSettingsView は不要になったため削除
// PlanStatusCard も PaywallView で代用するため削除してもよいが、将来のために残すか、あるいはPaywallViewのデザインに統一するか。
// 今回はPaywallViewを直接呼ぶので、ここにあるPlanSettingsViewは削除します。

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal, 24)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var iconColor: Color = Color(hex: "E07A5F")
    var showChevron: Bool = true
    var showDivider: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(hex: "3D405B").opacity(0.3))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            if showDivider {
                Divider()
                    .padding(.leading, 64)
            }
        }
        .contentShape(Rectangle()) // タップ領域を確保
    }
}

struct LanguageSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
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
            
            List {
                ForEach(Language.allCases) { language in
                    Button {
                        languageManager.currentLanguage = language
                        // 言語変更を反映するために少し遅延を入れてから閉じる
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B"))
                            
                            Spacer()
                            
                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(hex: "E07A5F"))
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
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
