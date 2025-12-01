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
                        
                        // 1. フリープラン
                        PlanCard(
                            title: L10n.freePlan.text,
                            price: L10n.freePrice.text,
                            features: [
                                (L10n.standardAI.text, true),
                                (L10n.limit3perDay.text, true),
                                (L10n.charLimit10k.text, true)
                            ],
                            themeColor: Color(hex: "81B29A"), // Green
                            isRecommended: false,
                            isCurrent: revenueCatService.currentPlan == .free,
                            buttonText: revenueCatService.currentPlan == .free ? L10n.currentPlan.text : L10n.restorePurchase.text // フリーに戻るという概念はないため
                        ) {
                            // フリープランへの変更アクション（通常は不要だが復元などを割り当て可能）
                        }
                        .disabled(true) // フリープランは選択不可（デフォルト）
                        
                        // 2. スタンダードプラン (Recommended)
                        PlanCard(
                            title: L10n.standardPlan.text,
                            price: L10n.standardPrice.text,
                            features: [
                                (L10n.standardAI.text, true),
                                (L10n.unlimitedScans.text, true),
                                (L10n.charLimit100k.text, true)
                            ],
                            themeColor: Color(hex: "E07A5F"), // Orange
                            isRecommended: true,
                            isCurrent: revenueCatService.currentPlan == .standard,
                            buttonText: revenueCatService.currentPlan == .standard ? L10n.currentPlan.text : "アップグレードする" // "Upgrade"
                        ) {
                            startPurchase(plan: .standard)
                        }
                        
                        // 3. プロプラン (Locked)
                        LockedPlanCard()
                        
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
    let title: String
    let price: String
    let features: [(String, Bool)] // (テキスト, 有効かどうか)
    let themeColor: Color
    let isRecommended: Bool
    let isCurrent: Bool
    let buttonText: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                // カード背景
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                // Recommended枠線
                if isRecommended {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeColor, lineWidth: 2)
                }
                
                VStack(spacing: 0) {
                    // ヘッダー部分
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B"))
                            
                            Text(price)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // アイコン
                        ZStack {
                            Circle()
                                .fill(themeColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: isRecommended ? "star.fill" : "leaf.fill")
                                .font(.system(size: 20))
                                .foregroundColor(themeColor)
                        }
                    }
                    .padding(20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // 機能リスト
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.0) { feature in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(themeColor)
                                
                                Text(feature.0)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Color(hex: "3D405B").opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    
                    Spacer(minLength: 0)
                    
                    // ボタン (現在のプランの場合は表示を変える)
                    if !isCurrent && isRecommended {
                        HStack {
                            Spacer()
                            Text(buttonText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(themeColor)
                                .cornerRadius(20)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    } else if isCurrent {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text(L10n.currentPlan.text)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(themeColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(themeColor.opacity(0.1))
                            .cornerRadius(12)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    } else {
                        // フリープランなどでボタンを表示しない場合、下の余白だけ確保
                         Color.clear.frame(height: 10)
                    }
                }
                
                // Recommendedバッジ (左上ではなく右上に配置して被りを防ぐ、あるいは上部中央)
                if isRecommended {
                    VStack {
                        HStack {
                            Spacer()
                            Text("RECOMMENDED")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeColor)
                                .cornerRadius(8)
                                .offset(y: -12) // カードの上に少しはみ出させる
                                .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ロックされたプロプランカード
struct LockedPlanCard: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            // カード背景
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.6))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            
            // ロックオーバーレイ
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(languageManager.currentLanguage == .japanese ? "プロプラン" : "Pro Plan")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            
                            Text(languageManager.currentLanguage == .japanese ? "準備中" : "Coming Soon")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.7))
                                .cornerRadius(8)
                        }
                        
                        Text(languageManager.currentLanguage == .japanese ? "¥980 / 月 (予定)" : "¥980 / Month (Planned)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding(20)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // 機能リスト
                VStack(alignment: .leading, spacing: 12) {
                    let features = languageManager.currentLanguage == .japanese ? [
                        "高性能AI (GPT-4o) 搭載",
                        "1日20回",
                        "1回100,000文字まで"
                    ] : [
                        "High-Performance AI (GPT-4o)",
                        "20 scans per day",
                        "100,000 characters per scan"
                    ]
                    
                    ForEach(features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.4))
                                .frame(width: 16, height: 16) // サイズ合わせ
                            
                            Text(feature)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.gray.opacity(0.7))
                            
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 10)
            }
        }
        .opacity(0.8)
    }
}
