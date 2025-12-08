import Foundation

struct AnalysisResult: Codable, Identifiable, Sendable {
    let id: UUID
    let contractType: String
    let risks: [RiskItem]
    let summary: String
    
    enum CodingKeys: String, CodingKey {
        case contractType = "contract_type"
        case risks
        case summary
    }
    
    init(contractType: String, risks: [RiskItem], summary: String) {
        self.id = UUID()
        self.contractType = contractType
        self.risks = risks
        self.summary = summary
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.contractType = try container.decode(String.self, forKey: .contractType)
        self.risks = try container.decode([RiskItem].self, forKey: .risks)
        self.summary = try container.decode(String.self, forKey: .summary)
    }
}

struct RiskItem: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let quote: String
    let severity: RiskSeverity
    let description: String
    let suggestion: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case quote
        case severity
        case description
        case suggestion
    }
    
    init(title: String, quote: String, severity: RiskSeverity, description: String, suggestion: String) {
        self.id = UUID()
        self.title = title
        self.quote = quote
        self.severity = severity
        self.description = description
        self.suggestion = suggestion
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        // titleがない場合のフォールバック（後方互換性のため）
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "検出されたリスク"
        self.quote = try container.decode(String.self, forKey: .quote)
        self.severity = try container.decode(RiskSeverity.self, forKey: .severity)
        self.description = try container.decode(String.self, forKey: .description)
        self.suggestion = try container.decode(String.self, forKey: .suggestion)
    }
}

enum RiskSeverity: String, Codable, Sendable {
    case high
    case medium
    case low
    case info
    
    var colorStr: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "yellow"
        case .info: return "blue"
        }
    }
}
