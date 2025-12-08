import Foundation
import PDFKit
import UIKit

class SampleContractGenerator {
    static let shared = SampleContractGenerator()
    
    private init() {}
    
    func generateSampleServiceAgreement() -> URL? {
        let text = """
        業務委託契約書
        
        本契約は、甲（以下「発注者」という）と乙（以下「受託者」という）との間で、以下の条件により業務委託契約を締結する。
        
        第1条（業務内容）
        受託者は、発注者の指示に従い、ウェブサイトのデザイン制作業務を行う。
        
        第2条（報酬）
        1. 報酬は、業務完了後、発注者の検収が完了した時点で支払うものとする。
        2. 報酬額は、別途発注者が指定する金額とする。
        
        第3条（損害賠償）
        受託者は、本業務に関連して発注者に生じた一切の損害について、その原因の如何を問わず、全額を賠償する責任を負う。
        
        第4条（知的財産権）
        本業務により生じた成果物の著作権（著作権法第27条及び第28条に定める権利を含む）は、すべて発注者に帰属する。
        
        第5条（契約の解除）
        発注者は、受託者の業務が不適切と判断した場合、事前の通知なく直ちに本契約を解除することができる。
        
        第6条（再委託の禁止）
        受託者は、本業務の全部または一部を第三者に再委託してはならない。
        
        第7条（守秘義務）
        受託者は、本業務に関連して知り得た一切の情報について、無期限に守秘義務を負う。
        
        以上
        
        甲（発注者）　株式会社サンプル
        乙（受託者）　フリーランス太郎
        """
        
        return createPDF(from: text, filename: "sample_service_agreement.pdf")
    }
    
    func generateSampleNDA() -> URL? {
        let text = """
        秘密保持契約書
        
        本契約は、甲（以下「開示者」という）と乙（以下「受領者」という）との間で、機密情報の取り扱いについて定める。
        
        第1条（機密情報の定義）
        本契約において「機密情報」とは、開示者が受領者に対して開示する一切の情報をいう。
        
        第2条（守秘義務）
        受領者は、機密情報を第三者に開示してはならない。また、本契約の目的以外に使用してはならない。
        
        第3条（損害賠償）
        受領者が本契約に違反した場合、開示者に生じた一切の損害を賠償する。
        
        第4条（契約期間）
        本契約の有効期間は、機密情報の開示日から10年間とする。
        
        以上
        
        甲（開示者）　株式会社テック
        乙（受領者）　開発者花子
        """
        
        return createPDF(from: text, filename: "sample_nda.pdf")
    }
    
    func generateSampleLease() -> URL? {
        let text = """
        賃貸借契約書
        
        本契約は、甲（以下「貸主」という）と乙（以下「借主」という）との間で、以下の物件の賃貸借について定める。
        
        第1条（物件）
        所在地：東京都渋谷区サンプル1-2-3
        物件名：サンプルマンション101号室
        
        第2条（賃料）
        月額賃料は10万円とし、毎月末日までに貸主の指定する口座に振り込むものとする。
        
        第3条（敷金・礼金）
        敷金は家賃2ヶ月分、礼金は家賃1ヶ月分とする。
        
        第4条（原状回復）
        借主は、退去時に原状回復のため、貸主が指定する業者によるクリーニング費用を全額負担する。
        
        第5条（契約期間）
        本契約の期間は、2024年1月1日から2025年12月31日までとする。
        
        第6条（契約の解除）
        借主が家賃を1ヶ月以上滞納した場合、貸主は催告なくして本契約を解除できる。
        
        以上
        
        甲（貸主）　不動産管理株式会社
        乙（借主）　借主次郎
        """
        
        return createPDF(from: text, filename: "sample_lease.pdf")
    }
    
    private func createPDF(from text: String, filename: String) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "TrapFinder",
            kCGPDFContextTitle: filename
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textRect = CGRect(x: 72, y: 72, width: pageWidth - 144, height: pageHeight - 144)
            attributedText.draw(in: textRect)
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("PDF保存エラー: \(error)")
            return nil
        }
    }
}
