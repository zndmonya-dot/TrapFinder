import SwiftUI

struct PaywallView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var isPurchasing = false
    @State private var showSuccessAlert = false
    
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
                    VStack(spacing: 20) {
                        // ヘッダー
                        VStack(spacing: 8) {
                            Text(L10n.upgradeTitle.text)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B"))
                            
                            Text(L10n.upgradeSubtitle.text)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // --- プラン比較カード (縦並び) ---
                        VStack(spacing: 16) {
                            ForEach(planCardConfigs) { config in
                                PlanCard(config: config)
                            }
                        }
                        
                        // --- フッター (法的情報) ---
                        VStack(spacing: 16) {
                            HStack(spacing: 20) {
                                NavigationLink(destination: TermsView()) {
                                    Text(L10n.terms.text)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                }
                                
                                Color(hex: "3D405B").opacity(0.2)
                                    .frame(width: 1, height: 12)
                                
                                NavigationLink(destination: PrivacyPolicyView()) {
                                    Text(L10n.privacy.text)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                }
                                
                                Color(hex: "3D405B").opacity(0.2)
                                    .frame(width: 1, height: 12)
                                
                                Button(action: {
                                    revenueCatService.restorePurchases { success in
                                        if success { presentationMode.wrappedValue.dismiss() }
                                    }
                                }) {
                                    Text(L10n.restorePurchase.text)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                                }
                            }
                            
                            // Apple審査用免責事項 (必須)
                            // デザインを崩さないよう、小さく表示
                            Text(subscriptionDisclaimer)
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text(L10n.purchaseSuccessTitle.text),
                    message: Text(L10n.purchaseSuccessMsg.text),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .id(languageManager.currentLanguage.id)
    }
    
    private var planCardConfigs: [PlanCardConfiguration] {
        let freeFeatures = [
            PlanFeature(text: L10n.standardAI.text),
            PlanFeature(text: L10n.limit3perDay.text),
            PlanFeature(text: L10n.charLimit10k.text)
        ]
        
        let standardFeatures = [
            PlanFeature(text: L10n.standardAI.text),
            PlanFeature(text: L10n.unlimitedScans.text),
            PlanFeature(text: L10n.charLimit100k.text)
        ]
        
        let proFeatures = [
            PlanFeature(text: L10n.highPerformanceAI.text),
            PlanFeature(text: L10n.limit20perDay.text),
            PlanFeature(text: L10n.charLimit100k.text)
        ]
        
        let isStandard = revenueCatService.currentPlan == .standard
        let isFree = revenueCatService.currentPlan == .free
        
        return [
            PlanCardConfiguration(
                tier: .free,
                title: L10n.freePlan.text,
                price: L10n.freePrice.text,
                features: freeFeatures,
                accentColor: Color(hex: "81B29A"),
                icon: "leaf.fill",
                badge: nil,
                drawsAccentBorder: false,
                isLocked: false,
                isCurrent: isFree,
                lockedMessage: nil,
                buttonTitle: nil,
                action: nil
            ),
            PlanCardConfiguration(
                tier: .standard,
                title: L10n.standardPlan.text,
                price: L10n.standardPrice.text,
                features: standardFeatures,
                accentColor: Color(hex: "E07A5F"),
                icon: "star.fill",
                badge: PlanCardConfiguration.Badge(
                    text: L10n.recommended.text,
                    background: Color(hex: "E07A5F")
                ),
                drawsAccentBorder: true,
                isLocked: false,
                isCurrent: isStandard,
                lockedMessage: nil,
                buttonTitle: isStandard ? nil : L10n.upgradeCta.text,
                action: isStandard ? nil : { startPurchase(plan: .standard) }
            ),
            PlanCardConfiguration(
                tier: .pro,
                title: L10n.proPlan.text,
                price: L10n.proPrice.text,
                features: proFeatures,
                accentColor: Color.gray,
                icon: "lock.fill",
                badge: PlanCardConfiguration.Badge(
                    text: L10n.comingSoon.text,
                    background: Color.gray.opacity(0.7)
                ),
                drawsAccentBorder: false,
                isLocked: true,
                isCurrent: false,
                lockedMessage: L10n.comingSoon.text,
                buttonTitle: nil,
                action: nil
            )
        ]
    }
    
    func startPurchase(plan: UserPlan) {
        guard revenueCatService.currentPlan != plan else { return }
        
        isPurchasing = true
        revenueCatService.purchase(plan: plan) { success in
            isPurchasing = false
            if success {
                showSuccessAlert = true
            }
        }
    }
    
    // 審査用免責事項テキスト
    private var subscriptionDisclaimer: String {
        if languageManager.currentLanguage == .japanese {
            return "お支払いは購入確認時にiTunesアカウントに請求されます。サブスクリプションは自動的に更新されますが、期間終了の24時間前までにアカウント設定で自動更新をオフにすることができます。更新料は期間終了前の24時間以内に請求されます。"
        } else {
            return "Payment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. Account will be charged for renewal within 24-hours prior to the end of the current period."
        }
    }
}

// --- 新しい比較用カードデザイン ---
struct PlanCard: View {
    let config: PlanCardConfiguration
    
    var body: some View {
        Group {
            if let action = config.action {
                Button(action: action) {
                    cardBody
                }
                .buttonStyle(.plain)
            } else {
                cardBody
            }
        }
        .opacity(config.isLocked ? 0.75 : 1)
    }
    
    private var cardBody: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            
            if config.drawsAccentBorder {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(config.accentColor, lineWidth: 2)
            }
            
            VStack(spacing: 0) {
                header
                Divider()
                    .padding(.horizontal, 20)
                featureList
                footer
            }
            
            if let badge = config.badge {
                Text(badge.text)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badge.background)
                    .cornerRadius(8)
                    .offset(y: -12)
                    .padding(.trailing, 20)
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                
                Text(config.price)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B").opacity(0.7))
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(config.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: config.icon)
                    .font(.system(size: 20))
                    .foregroundColor(config.isLocked ? Color.gray : config.accentColor)
            }
        }
        .padding(20)
    }
    
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(config.features) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: config.isLocked ? "lock.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(config.isLocked ? Color.gray.opacity(0.5) : config.accentColor)
                        .frame(width: 20, alignment: .leading)
                    
                    Text(feature.text)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(config.isLocked ? Color.gray.opacity(0.7) : Color(hex: "3D405B").opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var footer: some View {
        Group {
            if config.isLocked, let lockedMessage = config.lockedMessage {
                Text(lockedMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.gray)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            } else if config.isCurrent {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text(L10n.currentPlan.text)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(config.accentColor)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(config.accentColor.opacity(0.1))
                .cornerRadius(20)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            } else if let buttonTitle = config.buttonTitle, config.action != nil {
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(config.accentColor)
                    .cornerRadius(24)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            } else {
                Color.clear.frame(height: 8)
                    .padding(.bottom, 12)
            }
        }
    }
}

struct PlanCardConfiguration: Identifiable {
    enum Tier: String {
        case free, standard, pro
    }
    
    struct Badge {
        let text: String
        let background: Color
    }
    
    let tier: Tier
    let title: String
    let price: String
    let features: [PlanFeature]
    let accentColor: Color
    let icon: String
    let badge: Badge?
    let drawsAccentBorder: Bool
    let isLocked: Bool
    let isCurrent: Bool
    let lockedMessage: String?
    let buttonTitle: String?
    let action: (() -> Void)?
    
    var id: String { tier.rawValue }
}

struct PlanFeature: Identifiable {
    let id = UUID()
    let text: String
}
