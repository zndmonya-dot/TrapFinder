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
                    VStack(spacing: 32) {
                        // ヘッダー
                        VStack(spacing: 16) {
                            Text(L10n.upgradeTitle.text)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B"))
                            
                            Text(L10n.upgradeSubtitle.text)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.top, 20)
                        
                        // プラン選択カード
                        VStack(spacing: 20) {
                            
                            // Standard Plan (Recommended)
                            PlanCard(
                                title: L10n.standardPlan.text,
                                price: L10n.standardPrice.text,
                                features: [
                                    L10n.standardAI.text, // GPT-4o-mini
                                    L10n.unlimitedScans.text, // 無制限
                                    L10n.charLimit20k.text,
                                    L10n.detailedAnalysis.text
                                ],
                                color: Color(hex: "E07A5F"), // Terracotta
                                isRecommended: true,
                                isCurrentPlan: revenueCatService.currentPlan == .standard
                            ) {
                                startPurchase(plan: .standard)
                            }
                            
                            // Free Plan
                            PlanCard(
                                title: L10n.freePlan.text,
                                price: L10n.freePrice.text,
                                features: [
                                    L10n.standardAI.text, // GPT-4o-mini
                                    L10n.limit3perDay.text, // 1日3回
                                    L10n.charLimit5k.text,
                                    L10n.detailedAnalysis.text
                                ],
                                color: Color(hex: "81B29A"), // Sage Green
                                isRecommended: false,
                                isCurrentPlan: revenueCatService.currentPlan == .free
                            ) {
                                startPurchase(plan: .free)
                            }
                        }
                        .padding(.horizontal)
                        
                        // フッター
                        HStack(spacing: 20) {
                            Button(action: {}) {
                                Text(L10n.terms.text)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                            }
                            Button(action: {}) {
                                Text(L10n.privacy.text)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                            }
                            Button(action: {
                                revenueCatService.restorePurchases { success in
                                    if success { presentationMode.wrappedValue.dismiss() }
                                }
                            }) {
                                Text(L10n.restorePurchase.text)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.3))
                                .padding()
                        }
                    }
                    Spacer()
                }
            )
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
    
    func startPurchase(plan: UserPlan) {
        // 既に現在のプランなら何もしない（念のため）
        guard revenueCatService.currentPlan != plan else { return }
        
        isPurchasing = true
        revenueCatService.purchase(plan: plan) { success in
            isPurchasing = false
            if success {
                showSuccessAlert = true
            }
        }
    }
}

struct PlanCard: View {
    let title: String
    let price: String
    let features: [String]
    let color: Color
    let isRecommended: Bool
    let isCurrentPlan: Bool // 現在のプランかどうか
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 16) {
                    Text(title)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(isRecommended ? .white : Color(hex: "3D405B"))
                    
                    Text(price)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(isRecommended ? .white.opacity(0.9) : Color(hex: "3D405B").opacity(0.8))
                    
                    Divider()
                        .background(isRecommended ? .white.opacity(0.3) : Color.gray.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.self) { feature in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(isRecommended ? .white : color)
                                Text(feature)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(isRecommended ? .white : Color(hex: "3D405B"))
                                Spacer()
                            }
                        }
                    }
                    
                    // 現在のプラン、または購入ボタンの表示
                    if isCurrentPlan {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text(L10n.currentPlan.text)
                        }
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundColor(isRecommended ? color : .white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isRecommended ? .white : color)
                        .cornerRadius(12)
                        .padding(.top, 12)
                    } else {
                         // 選択ボタン（またはアップグレード）
                         Text(L10n.upgradeToPro.text) // "アップグレード" or "選択"的な文言が望ましいが、既存のL10nを使用
                             .font(.system(.callout, design: .rounded).weight(.bold))
                             .foregroundColor(isRecommended ? color : .white)
                             .padding(.vertical, 10)
                             .frame(maxWidth: .infinity)
                             .background(isRecommended ? .white : color)
                             .cornerRadius(12)
                             .padding(.top, 12)
                    }
                }
                .padding(24)
                .background(isRecommended ? color : Color.white)
                .cornerRadius(24)
                .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
                
                if isRecommended && !isCurrentPlan {
                    Text("RECOMMENDED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(16)
                }
            }
        }
        .disabled(isCurrentPlan) // 現在のプランなら押せない
    }
}
