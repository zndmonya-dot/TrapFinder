import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResult
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    headerSection
                    riskSection
                    disclaimerSection
                }
                .padding(.top, 30)
                .padding(.bottom, 60)
            }
            .background(Color(hex: "FFF8F0").ignoresSafeArea())
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
                ShareSheet(activityItems: [reportGenerator.generate()])
            }
        }
    }
    
    private var reportGenerator: ReportGenerator {
        ReportGenerator(result: result, language: languageManager.currentLanguage)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        AnalysisHeaderView(result: result)
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var riskSection: some View {
        RiskListView(risks: result.risks)
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var disclaimerSection: some View {
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
}

// MARK: - Components

private struct AnalysisHeaderView: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(spacing: 24) {
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
                    .foregroundColor(Color(hex: "3D405B"))
                    .multilineTextAlignment(.center)
                
                Text(result.summary)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Color(hex: "3D405B").opacity(0.8))
                    .lineSpacing(6)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
    }
}

private struct RiskListView: View {
    let risks: [RiskItem]
    
    var body: some View {
        if risks.isEmpty {
            EmptyRiskView()
        } else {
            VStack(spacing: 20) {
                header
                ForEach(Array(risks.enumerated()), id: \.element.id) { index, risk in
                    RiskCardView(risk: risk, index: index + 1)
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .foregroundColor(Color(hex: "E07A5F"))
            Text(L10n.risksDetected.text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "E07A5F"))
            Spacer()
            Text("\(risks.count)\(L10n.items.text)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "E07A5F"))
                .clipShape(Capsule())
        }
    }
}

private struct ReportGenerator {
    let result: AnalysisResult
    let language: Language
    
    func generate() -> String {
        var builder = [String]()
        builder.append(L10n.reportTitle.text)
        builder.append("\(L10n.reportDate.text): \(formattedDate())")
        builder.append("")
        builder.append(L10n.documentType.text)
        builder.append(result.contractType)
        builder.append("")
        builder.append(L10n.summarySection.text)
        builder.append(result.summary)
        builder.append("")
        builder.append("--------------------------------------------------")
        builder.append("")
        
        if result.risks.isEmpty {
            builder.append(L10n.noIssuesFound.text)
        } else {
            builder.append(String(format: L10n.checkPoints.text, result.risks.count))
            builder.append("")
            result.risks.enumerated().forEach { index, risk in
                builder.append(contentsOf: riskBlock(for: risk, index: index + 1))
            }
        }
        
        builder.append("--------------------------------------------------")
        builder.append(L10n.reportFooter.text)
        return builder.joined(separator: "\n")
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .japanese ? "ja_JP" : "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
    
    private func riskBlock(for risk: RiskItem, index: Int) -> [String] {
        var lines: [String] = []
        lines.append("\(index). \(label(for: risk.severity)) \(risk.title)")
        lines.append("")
        lines.append(L10n.originalText.text)
        lines.append("\"\(risk.quote)\"")
        lines.append("")
        lines.append(L10n.explanationSection.text)
        lines.append(risk.description)
        lines.append("")
        lines.append(L10n.advice.text)
        lines.append(risk.suggestion)
        lines.append("")
        return lines
    }
    
    private func label(for severity: RiskSeverity) -> String {
        switch severity {
        case .high: return language == .japanese ? "[重要]" : "[ALERT]"
        case .medium: return language == .japanese ? "[注意]" : "[WARN]"
        case .low: return language == .japanese ? "[確認]" : "[NOTE]"
        case .info: return language == .japanese ? "[情報]" : "[INFO]"
        }
    }
}

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
    
    private var severityStyle: RiskSeverityStyle {
        RiskSeverityStyle(for: risk.severity)
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
                            Text(severityStyle.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(severityStyle.textColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(severityStyle.background)
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

private struct RiskSeverityStyle {
    let label: String
    let background: Color
    let textColor: Color
    
    init(for severity: RiskSeverity) {
        switch severity {
        case .high:
            label = L10n.high.text
            background = Color(hex: "E07A5F")
            textColor = .white
        case .medium:
            label = L10n.medium.text
            background = Color(hex: "F2CC8F")
            textColor = Color(hex: "3D405B")
        case .low:
            label = L10n.low.text
            background = Color(hex: "81B29A")
            textColor = .white
        case .info:
            label = L10n.info.text
            background = Color(hex: "3D405B")
            textColor = .white
        }
    }
}
