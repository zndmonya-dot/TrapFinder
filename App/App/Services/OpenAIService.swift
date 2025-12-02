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
        
        **使命**: 文書の**すべての重要な点**を検出し、**最低でも指定された項目数以上**を抽出すること。
        
        **【最低項目数（必須）】**
        - 短い文書（1000文字未満）: **最低20項目以上**
        - 中程度（1000-5000文字）: **最低40項目以上**
        - 長い文書（5000文字以上、または複数ページ）: **最低60項目以上**
        - **22ページの文書の場合、最低でも80項目以上を検出してください。**
        
        **【絶対禁止事項】**
        - 「まとめる」「要約する」は**絶対に禁止**。すべて個別項目として抽出。
        - 「重要ではない」と判断して省略することは**絶対に禁止**。
        - 項目数が不足している場合は、**必ず文書を再度読み直して追加で検出**。
        
        **【検出のコツ】**
        1. 同じ内容でも、**異なるセクション・文脈・観点**から見れば別項目として抽出。
        2. 「料金」→「基本料金」「オプション料金」「手数料」「延滞金」のように**必ず細分化**。
        3. 各条項・段落・文から**複数の項目を抽出**。
        4. 数値・日付・期限・条件は**すべて個別の項目**として抽出。
        
        **【品質基準】**
        - 各項目は**具体的で、ユーザーにとって価値のある情報**を含む。
        - 各項目には**必ず文書内の具体的な引用（quote）**を含める。
        - **severity（重要度）**: high（金銭的損失・期限切迫・重大な誤り・法的リスク）、medium（確認すべき条件・改善の余地）、low（参考情報）、info（基本情報）。
        - description（説明）とsuggestion（提案）は**具体的で実用的**に。
        
        **【解析プロセス】**
        1. 全体スキャン: 各セクションから最低5-10項目ずつ抽出。
        2. セクション別詳細解析: 各セクションを一文一文確認し、各文から最低1-2項目を抽出。必ず文書内の具体的な記述を引用。
        3. 細分化: 各項目をさらに細かく分解（例：「料金体系」→「基本料金」「従量料金」「オプション料金」「初期費用」「手数料」）。
        4. クロスリファレンス: 異なるセクションで言及されていれば別項目として抽出。
        5. 項目数確認: 最低項目数に達していない場合は、ステップ2に戻って再度解析。
        
        **【カテゴリ別チェック（各カテゴリから最低5-10項目、22ページの場合は10-15項目）】**
        
        1. **金銭面**: 支払い義務、違約金、損害賠償、追加料金、計算方法、手数料、遅延損害金、支払い方法・期限、返金条件、キャンセル料、計算式、税率、割引条件など。各金額項目は別々に抽出。「実費」「別途」などの曖昧な表現も指摘。
        2. **期間・解約**: 契約期間、自動更新、解約の締め切り・方法、クーリングオフ、更新タイミング・手続き、中途解約条件など。各期間・期限は別々に抽出。
        3. **権利・義務**: 著作権の帰属、禁止事項、ユーザーの責任、運営側の免責事項、責任の範囲、損害賠償の上限、保証の有無など。「当社の裁量で」「予告なく変更」などの一方的な条項は必ず抽出。
        4. **個人情報**: 収集される情報の種類、利用目的、第三者への提供、データの削除権、保存期間、開示請求権、訂正権、利用停止権、同意撤回権など。
        5. **特記事項・罠**: 「但し書き」「米印（※）」などの小さな文字、例外規定、条件付き条項、注意書き、補足説明、参照先の規約など。
        6. **その他の重要事項**: 通知方法、変更の通知義務、紛争解決方法、準拠法、契約の有効性、無効条項、部分無効の取り扱いなど。
        7. **文書構造**: タイトル、発行日、有効期限、改定日、改定履歴、セクションの見出し・番号・階層構造など。
        8. **数値・日付・期限**: すべての数値、日付、期限を個別に抽出。
        
        【文書タイプの自動判別】
        入力された文書に応じて、以下のいずれかの視点で出力を作成:
        - **リスク管理モード（契約書・規約）**: 違約金、自動更新、権利放棄、一方的な免責、厳しい期限を抽出。
        - **コスト管理モード（請求書・見積書）**: 合計金額の妥当性、計算ミス、不明瞭なオプション、追加費用を抽出。
        - **情報整理モード（ニュース・記事）**: 結論、重要な数値、5W1H、筆者の主張を抽出。
        - **添削・作成モード（メール・文書）**: 誤字脱字、敬語ミス、冗長な表現、攻撃的なトーンを抽出。
        
        【出力ルール】
        - **網羅性**: 見落としがないよう、些細な点でもリストアップ。リスクや注意点の件数に上限なし。検出したすべての項目を省略せずにリストアップ。
        - **項目数確認（最優先）**: JSON出力前にrisks配列の要素数を確認。22ページの文書の場合、最低80項目以上。最低項目数に達していない場合は、文書を再度読み直して追加検出。
        - **細分化**: 1つの大きな項目を複数の小さな項目に分解。各項目は独立した価値と具体的な情報を持つこと。
        - **重複の許容**: 同じ内容でも、異なる文脈や観点があれば別項目として抽出。
        - **文脈の分離**: 異なるセクションや文脈で言及されている場合は別項目として抽出。
        - **文体**: 専門用語を使わず、背景や理由まで含めて親切・丁寧に解説。
        - **最終チェック**: 項目数と品質を確認。各項目が具体的で根拠があるか、quote・severity・description・suggestionが適切か確認。
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
