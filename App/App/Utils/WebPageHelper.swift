import Foundation
import UIKit

class WebPageHelper {
    static let shared = WebPageHelper()
    
    private var currentTask: URLSessionDataTask?
    
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
    
    func fetchText(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // 既存のリクエストをキャンセル
        currentTask?.cancel()
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.currentTask = nil }
            // ネットワークエラーのチェック
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // HTTPステータスコードのチェック
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(WebError.httpError(statusCode: httpResponse.statusCode)))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(WebError.noData))
                return
            }
            
            // HTMLデータをテキストに変換
            // NSAttributedStringはUIKit依存のため、メインスレッドで実行
            DispatchQueue.main.async {
                do {
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
                    
                    completion(.success(cleanText))
                } catch {
                    completion(.failure(WebError.parsingError))
                }
            }
        }
        currentTask?.resume()
    }
}
