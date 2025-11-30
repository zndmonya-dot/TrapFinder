import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResult
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var languageManager = LanguageManager.shared
    
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // ヘッダー（スコア表示を削除し、文書タイプと要約を中心に配置）
                    VStack(spacing: 24) {
                        // 文書タイプのアイコン（汎用的なドキュメントアイコン）
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "E07A5F"))
                            .padding(20)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "E07A5F").opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 12) {
                            Text(result.contractType)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .fontWeight(.heavy) // より強調
                                .foregroundColor(Color(hex: "3D405B"))
                                .multilineTextAlignment(.center)
                            
                            Text(result.summary)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(Color(hex: "3D405B").opacity(0.8))
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 30)
                    
                    // リスクカード一覧
                    if result.risks.isEmpty {
                        EmptyRiskView()
                    } else {
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle.portrait.fill")
                                    .foregroundColor(Color(hex: "E07A5F"))
                                Text(L10n.risksDetected.text)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "E07A5F"))
                                Spacer()
                                
                                // 件数バッジ
                                Text("\(result.risks.count)件")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "E07A5F"))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 24)
                            
                            ForEach(Array(result.risks.enumerated()), id: \.element.id) { index, risk in
                                RiskCardView(risk: risk, index: index + 1)
                            }
                        }
                    }
                    
                    // 免責事項（フッター）
                    VStack(spacing: 8) {
                        Text("免責事項")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.6))
                        
                        Text(L10n.legalText1.text) // "本アプリは、文書の読解を補助するAIツールです..."
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 40)
                        
                        Text(L10n.legalText2.text) // "最終判断はご自身で..."
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)
                }
                .padding(.bottom, 60)
            }
            .background(Color(hex: "FFF8F0").ignoresSafeArea()) // 共通の背景色
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill") // 閉じるボタンも見やすく
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.3))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "E07A5F"))
                    }
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(activityItems: [generateReportText()])
            }
        }
    }
    
    private func generateReportText() -> String {
        let dateFormatter = DateFormatter()
        let localeIdentifier = languageManager.currentLanguage == .japanese ? "ja_JP" : "en_US"
        dateFormatter.locale = Locale(identifier: localeIdentifier)
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: Date())
        
        var text = """
        【TrapFinder 解析レポート】
        実施日: \(dateString)
        
        ■ 文書の種類
        \(result.contractType)
        
        ■ 概要
        \(result.summary)
        
        --------------------------------------------------
        
        """
        
        if result.risks.isEmpty {
            text += "\n特筆すべき確認事項は検出されませんでした。\n"
        } else {
            text += "■ 確認ポイント（\(result.risks.count)件）\n\n"
            
            for (index, risk) in result.risks.enumerated() {
                let severityLabel: String
                switch risk.severity {
                case .high: severityLabel = "[重要]"
                case .medium: severityLabel = "[注意]"
                case .low: severityLabel = "[確認]"
                case .info: severityLabel = "[情報]"
                }
                
                text += """
                \(index + 1). \(severityLabel) \(risk.title)
                
                【原文】
                "\(risk.quote)"
                
                【解説】
                \(risk.description)
                
                【アドバイス】
                \(risk.suggestion)
                
                
                """
            }
        }
        
        text += """
        --------------------------------------------------
        ※このレポートはAIによって生成された読解補助情報です。
        ※法的助言ではありません。最終的な判断はご自身で行ってください。
        """
        
        return text
    }
}

// MARK: - Components

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RiskCardView: View {
    let risk: RiskItem
    let index: Int
    
    var severityColor: Color {
        switch risk.severity {
        case .high: return Color(hex: "E07A5F") // Terracotta
        case .medium: return Color(hex: "F2CC8F") // Mustard
        case .low: return Color(hex: "81B29A") // Sage Green
        case .info: return Color(hex: "3D405B") // Charcoal
        }
    }
    
    var severityTextColor: Color {
        // 背景色が明るい場合(Medium)は黒文字にする、他は白文字
        switch risk.severity {
        case .medium: return Color(hex: "3D405B")
        default: return .white
        }
    }
    
    var severityText: String {
        switch risk.severity {
        case .high: return L10n.high.text
        case .medium: return L10n.medium.text
        case .low: return L10n.low.text
        case .info: return L10n.info.text
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(severityText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(severityTextColor) // 文字色を調整
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor)
                    .cornerRadius(8)
                Spacer()
            }
            .padding([.top, .horizontal], 16)
            
            Text("\(index). \(risk.title)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "3D405B"))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 16) {
                if !risk.quote.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.quote.text)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                        
                        Text(risk.quote)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B"))
                            .lineSpacing(4)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "F4F1DE")) // 背景色を少し濃く（opacity削除）
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1) // 枠線を追加して視認性向上
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.explanation.text)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .fontWeight(.bold)
                    
                    Text(risk.description)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "3D405B"))
                        .lineSpacing(4)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(Color(hex: "E07A5F"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Text(L10n.suggestion.text) // "チェックの視点" / "アドバイス"
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "E07A5F"))
                        Spacer()
                    }
                    
                    Text(risk.suggestion)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "3D405B"))
                        .lineSpacing(4)
                }
                .padding(12)
                .background(Color(hex: "E07A5F").opacity(0.1))
                .cornerRadius(12)
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: "E07A5F").opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct EmptyRiskView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "81B29A"))
            
            VStack(spacing: 8) {
                Text("特筆すべき確認事項なし")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                Text("AIによるチェックでは、特に注意すべき点は見つかりませんでした。")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding()
    }
}
