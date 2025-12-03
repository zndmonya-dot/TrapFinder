import Foundation

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

class OpenAIService {
    static let shared = OpenAIService()
    private let apiKey = AppConfig.openAIAPIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
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
        case invalidURL
        case noData
        case decodingError
        case apiError(String)
    }
    
    // model引数を追加（デフォルトはgpt-4o-mini）
    func analyzeContract(text: String, model: String = "gpt-4o-mini", completion: @escaping (Result<AnalysisResult, Error>) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // HTTP圧縮を有効化（リクエストサイズ削減で転送時間短縮）
        request.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        // 長文解析に対応するため、タイムアウトを300秒（5分）に設定
        request.timeoutInterval = 300.0
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        
        do {
            request.httpBody = try requestBody(text: text, model: model, language: currentLanguage)
        } catch {
            completion(.failure(error))
            return
        }
        
        // 既存のリクエストをキャンセル
        currentTask?.cancel()
        
        // カスタムURLSessionConfigurationを作成（より長いタイムアウト設定とHTTP圧縮）
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0  // リクエストタイムアウト: 5分
        config.timeoutIntervalForResource = 600.0  // リソースタイムアウト: 10分
        // httpShouldUsePipeliningはiOS 18.4で非推奨のため削除（HTTP/2とHTTP/3が自動的に使用される）
        config.httpMaximumConnectionsPerHost = 2  // ホストあたりの最大接続数を2に設定
        let session = URLSession(configuration: config)
        
        currentTask = session.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.currentTask = nil }
            if let error = error {
                // タイムアウトエラーの詳細な処理
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    let currentLanguage = LanguageManager.shared.currentLanguage
                    let timeoutMessage = currentLanguage == .japanese 
                        ? "リクエストがタイムアウトしました。文書が長い場合、処理に時間がかかることがあります。しばらく待ってから再度お試しください。"
                        : "Request timed out. Long documents may take longer to process. Please wait a moment and try again."
                    completion(.failure(OpenAIError.apiError(timeoutMessage)))
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(format: L10n.httpError.text, httpResponse.statusCode)
                completion(.failure(OpenAIError.apiError(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            do {
                let aiResponse = try Self.decodeResponse(from: data)
                guard let content = aiResponse.choices.first?.message.content,
                      let contentData = content.data(using: .utf8) else {
                    completion(.failure(OpenAIError.decodingError))
                    return
                }
                
                let result = try Self.decodeAnalysisResult(from: contentData)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                #if DEBUG
                print("Decoding Error: \(error)")
                #endif
                completion(.failure(error))
            }
        }
        currentTask?.resume()
    }
    
    private func requestBody(text: String, model: String, language: Language) throws -> Data {
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt(for: language)],
            ["role": "user", "content": "以下の文書を解析してください。\n\n\(text)"]
        ]
        
        let parameters: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"],
            "temperature": 0.3,  // 処理速度向上のため0.3に調整（品質は維持）
            "max_tokens": 8000  // 出力トークン数を制限して処理時間を短縮
        ]
        
        return try JSONSerialization.data(withJSONObject: parameters)
    }
    
    private func systemPrompt(for language: Language) -> String {
        let outputLanguageInstruction = language == .japanese
        ? "- 言語: **必ず日本語で出力すること。**"
        : "- Language: **Output MUST be in English.**"
        
        let moneyInstruction = language == .japanese
        ? "- 金額やパーセンテージを検出したら、必ず数値・単位・条件をそのまま引用し、誤差や追加費用の可能性も説明してください。"
        : "- When monetary values or percentages appear, quote the exact numbers/units/conditions and explain hidden costs or uncertainties."
        
        return """
        【最重要】
        
        **使命**: ユーザーの意思決定や行動に必要な重要情報を**漏らさず・重複なく**抽出すること。
        
        **【項目数の目安】**
        - 短い文書（1000文字未満）: 10〜25件程度
        - 中程度（1000-5000文字）: 20〜45件程度
        - 長い文書（5000文字以上）: 40〜80件程度
        ※文書の情報密度や重要度により増減可。品質を優先し、不要な情報は出さない。
        
        **【基本方針】**
        1. **品質優先**: high/medium（行動が必要なリスクや条件）を中心に抽出。infoは補足として最小限。
        2. **重複排除**: 同じ条項番号・金額・期限は必ず統合。観点が異なる場合のみ別項目。
        3. **具体性**: すべての項目に引用・重要度・影響説明・推奨アクションを含める。
        
        **【抽出優先順位】**
        1. **金銭面**: 料金・違約金・損害賠償・追加費用・手数料・返金条件など。「別途」「実費」などの曖昧な表現も指摘。
        2. **期間・解約**: 契約期間・自動更新・解約条件・通知期限・クーリングオフなど。
        3. **権利・義務**: 免責事項・損害賠償上限・禁止事項・ユーザーの義務・一方的条項など。
        4. **個人情報**: 収集範囲・利用目的・第三者提供・削除権など。
        5. **例外・罠**: 但し書き・注釈・条件付き特典・リンク先の追加条件など。
        6. **構造情報**: 発効日・改定履歴・準拠法・紛争解決など。
        
        **【解析プロセス】**
        1. 文書全体を走査し、上記カテゴリから重要情報を抽出
        2. 同じ金額・条項・期限に関する重複を統合
        3. high/medium を優先し、infoは補足として最小限に抑える
        4. 最終チェック: 重要領域の抜け・重複・不要情報を確認
        
        **【品質基準】**
        - severity: high（金銭的損失・期限切迫・重大リスク）、medium（確認・交渉が必要）、low（参考情報）、info（背景情報、最小限）
        - 各項目に引用・説明・推奨アクションを含める
        
        【出力ルール】
        - **網羅性と品質のバランス**: 重要情報を漏らさないが、不要な情報は出さない
        - **重複統合**: 同じ金額・条項・期限は必ず1項目に統合。異なる観点の場合のみ別項目
        - **優先順位**: high/medium を優先し、infoは全体の30%以下に抑える
        - **文体**: 専門用語を避け、背景→影響→対策の順で簡潔に記述
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
