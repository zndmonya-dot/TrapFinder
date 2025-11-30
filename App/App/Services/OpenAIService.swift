import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    private let apiKey = AppConfig.openAIAPIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    // nonisolatedなデコード関数
    nonisolated private static func decodeAnalysisResult(from data: Data) throws -> AnalysisResult {
        return try JSONDecoder().decode(AnalysisResult.self, from: data)
    }
    
    enum OpenAIError: Error {
        case invalidURL
        case noData
        case decodingError
        case apiError(String)
    }
    
    // model引数を追加（デフォルトはgpt-4o）
    func analyzeContract(text: String, model: String = "gpt-4o", completion: @escaping (Result<AnalysisResult, Error>) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 現在の言語設定を取得
        let currentLanguage = LanguageManager.shared.currentLanguage
        
        // 言語ごとの出力指示
        let outputLanguageInstruction: String
        if currentLanguage == .japanese {
            outputLanguageInstruction = "- 言語: **必ず日本語で出力すること。**"
        } else {
            outputLanguageInstruction = "- Language: **Output MUST be in English.**"
        }
        
        // プロンプト設定（全面リニューアル）
        let systemPrompt = """
        あなたは、ユーザーの生活をサポートする**「万能ドキュメント解析AI」**です。
        入力されたテキストがどのような文書であっても、その本質を理解し、ユーザーが**「次に何をすべきか」「何に注意すべきか」**を瞬時に判断できる情報を提供してください。
        
        【思考プロセス：強制チェックリスト】
        解析を行う際は、以下の項目を**必ずひとつずつ確認**し、該当する記述があれば必ず抽出してください。
        
        1. **金銭面**: 支払い義務、違約金、損害賠償、追加料金、計算方法、振込手数料。
        2. **期間・解約**: 契約期間、自動更新の有無、解約の締め切り、解約方法、クーリングオフ。
        3. **権利・義務**: 著作権の帰属、禁止事項、ユーザーが負う責任、運営側の免責事項。
        4. **個人情報**: 収集される情報、利用目的、第三者への提供、データの削除権。
        5. **特記事項**: 「但し書き」「米印（※）」などの小さな文字、例外規定。
        
        AI独自の判断で「重要ではない」と省略することを固く禁じます。
        「疑わしきは抽出せよ」の精神で、少しでもユーザーに関係する記述はすべて `risks` 配列に含めてください。
        
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
        - 網羅性: **「見落とし」がないよう、些細な点でもリストアップしてください。** 数が多くなっても構いません。
        - 文体: ユーザーの頼れるパートナーとして、専門用語を使わず、**背景や理由まで含めて親切・丁寧に**解説してください。
        - 分量: **無理に短くまとめる必要はありません。** ユーザーが十分に理解できるよう、必要な情報をすべて盛り込んでください。
        \(outputLanguageInstruction)
        - 法的免責: 弁護士ではないため、法的な断定は避け「注意が必要です」「確認をお勧めします」という表現にとどめること。
        
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
        
        let parameters: [String: Any] = [
            "model": model, // 指定されたモデルを使用
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "以下の文書を解析してください。\n\n\(text)"]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = "HTTPエラー: \(httpResponse.statusCode)"
                    completion(.failure(OpenAIError.apiError(errorMessage)))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            do {
                struct OpenAIResponse: Decodable {
                    struct Choice: Decodable {
                        struct Message: Decodable {
                            let content: String
                        }
                        let message: Message
                    }
                    let choices: [Choice]
                }
                
                let aiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
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
}
