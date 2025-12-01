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
                                Text("\(result.risks.count)\(L10n.items.text)")
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
                    VStack(spacing: 4) {
                        Text(L10n.disclaimer.text)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                        
                        Text(L10n.reportFooter.text)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.4))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 10)
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
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        let dateLabel = currentLanguage == .japanese ? L10n.reportDate.text : L10n.reportDate.text
        
        var text = """
        \(L10n.reportTitle.text)
        \(dateLabel): \(dateString)
        
        \(L10n.documentType.text)
        \(result.contractType)
        
        \(L10n.summarySection.text)
        \(result.summary)
        
        --------------------------------------------------
        
        """
        
        if result.risks.isEmpty {
            text += "\n\(L10n.noIssuesFound.text)\n"
        } else {
            text += String(format: L10n.checkPoints.text, result.risks.count) + "\n\n"
            
            for (index, risk) in result.risks.enumerated() {
                let severityLabel: String
                switch risk.severity {
                case .high: severityLabel = currentLanguage == .japanese ? "[重要]" : "[ALERT]"
                case .medium: severityLabel = currentLanguage == .japanese ? "[注意]" : "[WARN]"
                case .low: severityLabel = currentLanguage == .japanese ? "[確認]" : "[NOTE]"
                case .info: severityLabel = currentLanguage == .japanese ? "[情報]" : "[INFO]"
                }
                
                text += """
                \(index + 1). \(severityLabel) \(risk.title)
                
                \(L10n.originalText.text)
                "\(risk.quote)"
                
                \(L10n.explanationSection.text)
                \(risk.description)
                
                \(L10n.advice.text)
                \(risk.suggestion)
                
                
                """
            }
        }
        
        text += """
        --------------------------------------------------
        \(L10n.reportFooter.text)
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
    @State private var isExpanded = false
    
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
            // ヘッダー部分（タップで展開）
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack {
                            Text(severityText)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(severityTextColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(severityColor)
                                .cornerRadius(8)
                            Spacer()
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "3D405B").opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 0 : 0))
                    }
                    
                    Text("\(index). \(risk.title)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "3D405B"))
                        .multilineTextAlignment(.leading)
                        .lineLimit(isExpanded ? nil : 2)
                }
                .padding(16)
            }
            
            // 詳細部分（展開時のみ表示）
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
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
                        Text(L10n.explanationSection.text)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity) // シンプルなフェードインに戻す
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: "E07A5F").opacity(0.1), radius: 10, x: 0, y: 5)
        // .clipped() // 削除
    }
}

struct EmptyRiskView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "81B29A"))
            
            VStack(spacing: 8) {
                Text(L10n.noIssuesTitle.text)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B"))
                Text(L10n.noIssuesMessage.text)
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
