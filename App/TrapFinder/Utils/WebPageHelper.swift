import Foundation
import UIKit

class WebPageHelper {
    static let shared = WebPageHelper()
    
    private var currentTask: Task<(Data, URLResponse), Error>?
    
    private init() {}
    
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    enum WebError: LocalizedError {
        case invalidURL
        case noData
        case parsingError
        case httpError(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "無効なURLです"
            case .noData:
                return "データを取得できませんでした"
            case .parsingError:
                return "ページの内容を解析できませんでした"
            case .httpError(let code):
                return "HTTPエラー (\(code)): ページにアクセスできませんでした"
            }
        }
    }
    
    /// async/await版のWebページテキスト取得
    func fetchText(from url: URL) async throws -> String {
        // 既存のリクエストをキャンセル
        cancelCurrentRequest()
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        // Taskを作成してキャンセル可能にする
        let task = Task {
            try await URLSession.shared.data(for: request)
        }
        
        // キャンセル可能にするためにcurrentTaskに保存
        currentTask = task
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await task.value
        } catch {
            currentTask = nil
            throw error
        }
        
        currentTask = nil
        
        // HTTPステータスコードのチェック
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw WebError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        // HTMLデータをテキストに変換
        // NSAttributedStringはUIKit依存のため、メインスレッドで実行
        return try await MainActor.run {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            let text = attributedString.string
            
            // 余分な空白行などを整理
            let cleanText = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            
            return cleanText
        }
    }
    
    /// 旧コールバック版（後方互換性のため残す）
    func fetchText(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let text = try await fetchText(from: url)
                completion(.success(text))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
