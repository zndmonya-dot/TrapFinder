import Foundation
import UIKit
import PDFKit

class PDFHelper {
    static func pdfToImages(url: URL) -> [UIImage] {
        guard let document = PDFDocument(url: url) else { return [] }
        var images: [UIImage] = []
        
        // ページごとに画像化
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            
            // メディアボックス（ページのサイズ）を取得
            let pageRect = page.bounds(for: .mediaBox)
            
            // 高解像度設定（スケールを2.0〜3.0に上げることで細かい文字も認識可能にする）
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3.0 // 3倍の解像度でレンダリング
            
            let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)
            
            let image = renderer.image { ctx in
                // 背景を白で塗りつぶす（透過PDF対策）
                UIColor.white.set()
                ctx.fill(pageRect)
                
                // 座標系の調整（PDFは左下が原点のため反転が必要）
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }
        
        return images
    }
}
