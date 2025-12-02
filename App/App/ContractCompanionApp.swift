import SwiftUI

@main
struct TrapFinderApp: App {
    @StateObject private var storeKitService = StoreKitService.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // アプリ全体をライトモードに固定
                .environmentObject(storeKitService)
                .environmentObject(languageManager)
        }
    }
}
