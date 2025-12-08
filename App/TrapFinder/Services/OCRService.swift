import Foundation
@preconcurrency import Vision
import UIKit

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    /// async/await版のOCR処理
    func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }
            
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Visionフレームワークの型は実際にはスレッドセーフだが、Sendableに準拠していないため
            // nonisolatedなコンテキストで実行
            DispatchQueue.global(qos: .userInitiated).async { [handler, request] in
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 旧コールバック版（後方互換性のため残す）
    func performOCR(on image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let text = try await performOCR(on: image)
                completion(.success(text))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "無効な画像です"
        }
    }
}
