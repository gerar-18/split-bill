import SwiftUI

@main struct MyApp: App {
    @State private var store = SwiftDataReceiptStore.live()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
