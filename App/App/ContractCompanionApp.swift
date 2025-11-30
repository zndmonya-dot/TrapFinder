import SwiftUI
import SwiftData

@main
struct KudasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // アプリ全体をライトモードに固定
        }
    }
}
