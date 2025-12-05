import Foundation

enum AppConfig {
    /// OpenAI APIキーはビルド時に注入する（環境変数 `OPENAI_API_KEY` か Info.plist の `OPENAI_API_KEY` を利用）
    static var openAIAPIKey: String {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        if let infoKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !infoKey.isEmpty {
            return infoKey
        }
        
        #if DEBUG
        print("WARNING: OpenAI API key is missing. Set OPENAI_API_KEY in env or Info.plist.")
        #endif
        return ""
    }
}
