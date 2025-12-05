import Foundation

@preconcurrency
private struct OpenAIRequest: Encodable, Sendable {
    struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }
    
    struct ResponseFormat: Encodable, Sendable {
        let type: String
    }
    
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case temperature
        case maxTokens = "max_tokens"
    }
}

@preconcurrency
private struct OpenAIResponse: Decodable, Sendable {
    @preconcurrency
    struct Choice: Decodable, Sendable {
        @preconcurrency
        struct Message: Decodable, Sendable {
            let content: String
            
            nonisolated init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: MessageCodingKeys.self)
                content = try container.decode(String.self, forKey: .content)
            }
            
            enum MessageCodingKeys: String, CodingKey {
                case content
            }
        }
        let message: Message
        
        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = try container.decode(Message.self, forKey: .message)
        }
        
        enum CodingKeys: String, CodingKey {
            case message
        }
    }
    let choices: [Choice]
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        choices = try container.decode([Choice].self, forKey: .choices)
    }
    
    enum CodingKeys: String, CodingKey {
        case choices
    }
}

extension OpenAIService.OpenAIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI APIキーが設定されていません。環境変数またはInfo.plistにOPENAI_API_KEYを設定してください。"
        case .invalidURL:
            return "無効なリクエストURLです。"
        case .noData:
            return "レスポンスが空でした。"
        case .decodingError:
            return "レスポンスの解析に失敗しました。"
        case .apiError(let message):
            return message
        }
    }
}

protocol OpenAIAnalyzing {
    func analyzeContract(text: String, model: String) async throws -> AnalysisResult
}

class OpenAIService: OpenAIAnalyzing {
    static let shared = OpenAIService()
    private var apiKey: String { AppConfig.openAIAPIKey }
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // 長文解析対応: リクエスト/リソースタイムアウトを長めに確保
        config.timeoutIntervalForRequest = 300.0
        config.timeoutIntervalForResource = 600.0
        // HTTP/2/3 を自動利用するため特別な設定は不要
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()
    
    // nonisolatedなJSONDecoderインスタンス（MainActorの制約を回避）
    nonisolated private static let jsonDecoder = JSONDecoder()
    
    // リクエストのキャンセル用
    private var currentTask: URLSessionDataTask?
    
    private init() {}
    
    /// 現在実行中のリクエストをキャンセル
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    nonisolated private static func decodeResponse(from data: Data) throws -> OpenAIResponse {
        try jsonDecoder.decode(OpenAIResponse.self, from: data)
    }
    
    nonisolated private static func decodeAnalysisResult(from contentData: Data) throws -> AnalysisResult {
        try jsonDecoder.decode(AnalysisResult.self, from: contentData)
    }
    
    enum OpenAIError: Error {
        case missingAPIKey
        case invalidURL
        case noData
        case decodingError
        case apiError(String)
    }
    
    /// async/await 版。UI側で Task によるキャンセルが可能。
    func analyzeContract(text: String, model: String = "gpt-4o-mini") async throws -> AnalysisResult {
        #if DEBUG
        let keyPreview = apiKey.isEmpty ? "空" : String(apiKey.prefix(6))
        print("[OpenAIService] ===== Analysis Start =====")
        print("[OpenAIService] API key empty? \(apiKey.isEmpty) prefix: \(keyPreview)")
        print("[OpenAIService] Text length: \(text.count) characters")
        print("[OpenAIService] Model: \(model)")
        #endif
        
        guard !apiKey.isEmpty else {
            #if DEBUG
            print("[OpenAIService] ERROR: API key is missing!")
            #endif
            throw OpenAIError.missingAPIKey
        }
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 300.0
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        request.httpBody = try requestBody(text: text, model: model, language: currentLanguage)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[OpenAIService] Network error: \(error.localizedDescription)")
            #endif
            throw OpenAIError.apiError("ネットワークエラー: \(error.localizedDescription)")
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            #if DEBUG
            print("[OpenAIService] HTTP status: \(httpResponse.statusCode)")
            #endif
            
            if !(200...299).contains(httpResponse.statusCode) {
                // エラーレスポンスの内容を取得
                let errorBody = String(data: data, encoding: .utf8) ?? "不明なエラー"
                #if DEBUG
                print("[OpenAIService] Error response body: \(errorBody)")
                #endif
                let errorMessage = String(format: L10n.httpError.text, httpResponse.statusCode)
                throw OpenAIError.apiError("\(errorMessage)\n詳細: \(errorBody)")
            }
        }
        
        #if DEBUG
        print("[OpenAIService] Response data size: \(data.count) bytes")
        #endif
        
        let aiResponse: OpenAIResponse
        do {
            aiResponse = try Self.decodeResponse(from: data)
        } catch {
            #if DEBUG
            print("[OpenAIService] Failed to decode response: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[OpenAIService] Response JSON: \(jsonString.prefix(500))")
            }
            #endif
            throw OpenAIError.decodingError
        }
        
        guard let content = aiResponse.choices.first?.message.content else {
            #if DEBUG
            print("[OpenAIService] No content in response. Choices count: \(aiResponse.choices.count)")
            #endif
            throw OpenAIError.decodingError
        }
        
        guard let contentData = content.data(using: .utf8) else {
            #if DEBUG
            print("[OpenAIService] Failed to convert content to data")
            #endif
            throw OpenAIError.decodingError
        }
        
        #if DEBUG
        print("[OpenAIService] Content length: \(content.count) characters")
        print("[OpenAIService] Content preview: \(content.prefix(200))")
        #endif
        
        do {
            return try Self.decodeAnalysisResult(from: contentData)
        } catch {
            #if DEBUG
            print("[OpenAIService] Failed to decode analysis result: \(error)")
            print("[OpenAIService] Content: \(content)")
            #endif
            throw OpenAIError.decodingError
        }
    }
    
    private func requestBody(text: String, model: String, language: Language) throws -> Data {
        // 文字数に応じてmax_tokensを動的に調整
        // 計算基準:
        // - 日本語は1文字≈0.3-0.4トークン（入力）
        // - 出力: 1項目あたり平均300-500トークン
        // - GPT-4o-miniの制限: 最大16384トークン
        // - GPT-4oの制限: 最大16384トークン（ただし、より多くの項目を返せる）
        let textLength = text.count
        
        // モデルごとの最大トークン制限
        let modelMaxTokens: Int
        if model.contains("gpt-4o") && !model.contains("mini") {
            // GPT-4oの場合
            modelMaxTokens = 16384
        } else {
            // GPT-4o-miniの場合
            modelMaxTokens = 16384
        }
        
        // 文字数に応じてmax_tokensを計算（ただしモデルの上限を超えない）
        // 文字数制限は80,000文字に変更されたため、それに合わせて調整
        let calculatedMaxTokens: Int
        if textLength <= 10_000 {
            // 短い文書: 10-25件想定 → 8,000-12,000トークン
            calculatedMaxTokens = 12_000
        } else if textLength <= 50_000 {
            // 中程度: 20-45件想定 → 12,000-16,000トークン
            calculatedMaxTokens = 16_000
        } else {
            // 長い文書（80,000文字まで）: 40-80件想定 → 最大16,000トークン
            calculatedMaxTokens = 16_000
        }
        
        // モデルの上限を超えないように調整
        let maxTokens = min(calculatedMaxTokens, modelMaxTokens)
        
        let request = OpenAIRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt(for: language)),
                .init(role: "user", content: "以下の文書を解析してください。\n\n\(text)")
            ],
            responseFormat: .init(type: "json_object"),
            temperature: 0.5,  // 0.3から0.5に上げて品質と創造性のバランスを改善
            maxTokens: maxTokens
        )
        
        return try JSONEncoder().encode(request)
    }
    
    private func systemPrompt(for language: Language) -> String {
        let outputLanguageInstruction = language == .japanese
        ? "- 言語: **必ず日本語で出力すること。**"
        : "- Language: **Output MUST be in English.**"
        
        let moneyInstruction = language == .japanese
        ? """
        - **金額の抽出を最優先**: 文書内のすべての金額・料金・費用を必ず抽出してください。
        - **数値の正確な引用**: 金額を検出したら、数値・単位・条件をそのまま引用してください（例：「月額980円」「初月無料」「解約金10,000円」）。
        - **曖昧な表現の指摘**: 「別途」「実費」「要相談」などの曖昧な表現は必ず指摘し、具体的な金額が不明であることを明記してください。
        - **隠れた費用の探索**: ページ下部、注釈、リンク先、別紙などに記載された追加費用を必ず探してください。
        - **条件付き料金の詳細化**: 条件付き料金（「初月無料」「3ヶ月間50%オフ」など）は、条件と通常料金を両方記載してください。
        - **返金条件の明確化**: 返金可能な場合・不可能な場合、返金手数料、返金期限などを詳細に記載してください。
        """
        : """
        - **Prioritize monetary extraction**: Extract ALL monetary values, fees, and costs from the document.
        - **Accurate number quoting**: When detecting amounts, quote exact numbers, units, and conditions (e.g., "Monthly fee: $9.80", "First month free", "Cancellation fee: $100").
        - **Highlight ambiguous expressions**: Always point out vague expressions like "separate", "actual cost", "contact us" and note that specific amounts are unclear.
        - **Search for hidden costs**: Always search for additional fees in footnotes, links, appendices, etc.
        - **Detail conditional pricing**: For conditional pricing ("first month free", "50% off for 3 months"), include both conditions and regular prices.
        - **Clarify refund conditions**: Detail refund eligibility, refund fees, refund deadlines, etc.
        """
        
        return """
        【最重要】
        
        **使命**: ユーザーの意思決定や行動に必要な重要情報を**漏らさず・重複なく**抽出すること。
        
        **【項目数の目安】**
        - 短い文書（1000文字未満）: **10〜25件**（重要情報を漏らさない範囲で）
        - 中程度（1000-5000文字）: **20〜45件**（文書の情報密度に応じて調整）
        - 長い文書（5000文字以上）: **40〜80件**（重要情報を網羅的に抽出）
        **重要**: 項目数よりも**品質と網羅性**を優先してください。重要でない情報を無理に増やすのではなく、ユーザーにとって本当に必要な情報を抽出することが最優先です。
        
        **【基本方針】**
        1. **品質と網羅性のバランス**: 重要情報を漏らさないが、不要な情報は出さない。各項目の説明は詳細で実用的なものにする。
        2. **重複排除**: 同じ条項番号・金額・期限は必ず統合。観点が異なる場合のみ別項目。
        3. **具体性と実用性**: すべての項目に引用・重要度・影響説明・推奨アクションを含め、ユーザーが実際に行動できる内容にする。
        
        **【抽出優先順位（金額を最優先）】**
        1. **金銭面（最優先）**: 
           - **すべての金額・料金・費用を必ず抽出**: 基本料金、月額料金、年額料金、初期費用、解約金、違約金、手数料、追加費用、延滞料、キャンセル料など
           - **数値と単位を正確に記載**: 「10,000円」「5%」「月額980円」など、数値・単位・条件をそのまま引用
           - **曖昧な表現を指摘**: 「別途」「実費」「要相談」「別途お問い合わせ」などの曖昧な表現は必ず指摘し、具体的な金額が不明であることを明記
           - **条件付き料金を詳細に**: 「初月無料」「3ヶ月間50%オフ」などの条件付き料金は、条件と通常料金を両方記載
           - **返金条件を明確に**: 返金可能な場合・不可能な場合、返金手数料、返金期限などを詳細に
           - **隠れた費用を探す**: ページ下部、注釈、リンク先、別紙などに記載された追加費用を必ず探す
        2. **期間・解約**: 契約期間・自動更新・解約条件・通知期限・クーリングオフなど。
        3. **権利・義務**: 免責事項・損害賠償上限・禁止事項・ユーザーの義務・一方的条項など。
        4. **個人情報**: 収集範囲・利用目的・第三者提供・削除権など。
        5. **例外・罠**: 但し書き・注釈・条件付き特典・リンク先の追加条件など。
        6. **構造情報**: 発効日・改定履歴・準拠法・紛争解決など。
        
        **【解析プロセス】**
        1. 文書全体を徹底的に走査し、上記カテゴリから**可能な限り多くの**重要情報を抽出
        2. 同じ金額・条項・期限に関する重複を統合（ただし、異なる観点の場合は別項目として抽出）
        3. high/medium を優先し、infoは補足として適切に含める（全体の30%以下を目安）
        4. **項目数が少なすぎないか確認**: 文書の長さに応じて、最低件数を満たしているか必ず確認
        5. 最終チェック: 重要領域の抜け・重複・不要情報を確認
        
        **【品質基準】**
        - severity: high（金銭的損失・期限切迫・重大リスク）、medium（確認・交渉が必要）、low（参考情報）、info（背景情報、最小限）
        - 各項目に引用・説明・推奨アクションを含める
        
        【出力ルール】
        - **品質と網羅性のバランス**: 重要情報を漏らさないことが最重要。ただし、項目数よりも各項目の品質と実用性を優先してください。
        - **重複統合**: 同じ金額・条項・期限は必ず1項目に統合。ただし、異なる観点（例：料金の金額と返金条件）の場合は別項目として抽出
        - **優先順位**: high/medium を優先し、infoは全体の30%以下に抑える。各項目の説明は詳細で実用的なものにする。
        - **文体**: 専門用語を避け、背景→影響→対策の順で簡潔かつ具体的に記述。ユーザーが理解しやすく、行動に移しやすい内容にする。
        - **最終確認**: 出力前に、重要情報が漏れていないか、各項目の説明が十分に詳細で実用的かを確認してください
        \(outputLanguageInstruction)
        \(moneyInstruction)
        - 法的免責: 弁護士ではないため、法的な断定は避け「注意が必要です」「確認をお勧めします」という表現にとどめること。
        - 追加チェック: リンクや注釈の先に費用や制限が隠れていないか推測し、調査または問い合わせを促してください。
        
        【JSON出力フォーマット】
        以下の形式のみを出力してください。Markdownは含めないでください。
        
        {
            "contract_type": "文書の種類（例：賃貸契約書、電気料金の請求書、ITニュース記事）",
            "summary": "詳細な要約（文書の目的、結論、重要な変更点などを、前提知識がないユーザーにも分かるように具体的に説明してください。）",
            "risks": [
                {
                    "title": "項目タイトル（例：解約違約金の発生条件について）",
                    "quote": "根拠となる箇所の抜粋（ない場合は空文字）",
                    "severity": "high" | "medium" | "low" | "info",
                    "description": "詳細な解説（なぜその点が重要なのか、放置するとどうなるか、一般的な相場との違いなど、ユーザーが納得できるように詳しく説明してください。）",
                    "suggestion": "具体的なアドバイス（次に取るべき行動、確認すべき資料、交渉の余地があるかなど、実用的な助言を記述してください。）"
                }
            ]
        }
        
        【重要度 (severity) の基準】
        - high: **最優先**（金銭的損失、期限切迫、重大な誤り、記事の結論）。
        - medium: **注意**（確認すべき条件、改善の余地がある表現、重要な補足）。
        - low: **参考**（知っておくと良い情報、些細な修正案）。
        - info: **基本情報**（金額、日付、場所など）。
        """
    }
}
