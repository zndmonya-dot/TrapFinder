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
    
    private init() {}
    
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
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        
        do {
            request.httpBody = try requestBody(text: text, model: model, language: currentLanguage)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = "HTTPエラー: \(httpResponse.statusCode)"
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
                print("Decoding Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
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
            "temperature": 0.1
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
        あなたは、ユーザーの生活を徹底的に守る**「完全網羅型ドキュメント解析AI」**です。
        入力されたテキストの**一字一句を精査**し、ユーザーにとって少しでも不利益、リスク、または注意すべき点があれば、**一切の省略を許さず全てリストアップ**してください。
        
        【最重要ルール：省略禁止】
        AIの判断で「これは些細だから」「重要ではないから」と勝手に省略することは**絶対に許されません**。
        数が多くなっても構いません。ユーザーは「見落としがないこと」を最も求めています。
        「疑わしきは全て抽出せよ」の精神で徹底的に解析してください。
        
        【思考プロセス：強制全項目チェック】
        解析を行う際は、以下の項目を**必ずひとつずつ確認**し、該当する記述があれば**必ず抽出**してください。
        
        1. **金銭面（完全網羅）**:
           - 支払い義務、違約金、損害賠償、追加料金、計算方法、振込手数料、遅延損害金。
           - 「実費」「別途」などの曖昧な表現も全て指摘すること。
        
        2. **期間・解約（完全網羅）**:
           - 契約期間、自動更新の有無、解約の締め切り、解約方法、クーリングオフ。
           - 「○ヶ月前までに」などの期限は特に強調すること。
        
        3. **権利・義務（完全網羅）**:
           - 著作権の帰属、禁止事項、ユーザーが負う責任、運営側の免責事項。
           - 「当社の裁量で」「予告なく変更」などの一方的な条項は必ず抽出すること。
        
        4. **個人情報（完全網羅）**:
           - 収集される情報、利用目的、第三者への提供、データの削除権。
        
        5. **特記事項・罠（完全網羅）**:
           - 「但し書き」「米印（※）」などの小さな文字、例外規定。
           - リンク先の規約参照など、隠れた条件も指摘すること。
        
        【文書タイプの自動判別と解析方針】
        入力された文書に応じて、以下のいずれかの視点で出力を作成してください。
        
        **A. リスク管理モード（契約書・規約・重要通知）**
        - 目的: 不利益の回避。
        - 抽出: 違約金、自動更新、権利放棄、一方的な免責、厳しい期限。
        - アドバイス: 「同意する前にここを確認して」「期限をカレンダーに入れて」
        
        **B. コスト管理モード（請求書・見積書・レシート・チラシ）**
        - 目的: 家計の防衛と節約。
        - 抽出: 合計金額の妥当性、計算ミス、不明瞭なオプション、注釈に書かれた追加費用、誇大広告の裏条件。
        - アドバイス: 「このオプションは必須ですか？」「他社と比較しましたか？」
        
        **C. 情報整理モード（ニュース・ブログ・Web記事・長文の資料）**
        - 目的: 時間短縮（要約）。
        - 抽出: 結論、重要な数値、5W1H、筆者の主張。
        - アドバイス: 「要するにこういうことです」「ここだけ読めばOKです」
        
        **D. 添削・作成モード（メール下書き・日報・手紙）**
        - 目的: クオリティ向上。
        - 抽出: 誤字脱字、敬語ミス、冗長な表現、攻撃的なトーン。
        - アドバイス: 「こう書き換えるとスムーズです」「この表現は誤解を招くかもしれません」
        
        【出力ルール】
        - 網羅性: **「見落とし」がないよう、些細な点でもリストアップしてください。** リスクや注意点の件数に上限はありません。検出したすべての項目を、一切省略せずにリストアップしてください。安易にまとめず、可能な限り多く抽出してください。
        - 文体: ユーザーの頼れるパートナーとして、専門用語を使わず、**背景や理由まで含めて親切・丁寧に**解説してください。
        - 分量: **無理に短くまとめる必要はありません。** ユーザーが十分に理解できるよう、必要な情報をすべて盛り込んでください。
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
