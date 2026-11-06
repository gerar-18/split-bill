import SwiftUI

@main struct MyApp: App {
    private let isRunningTests: Bool
    @State private var store: (any ReceiptPersistenceStore)?

    init() {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        self.isRunningTests = isTesting
        if isTesting {
            _store = State(initialValue: nil)
        } else {
            _store = State(initialValue: SwiftDataReceiptStore.live())
        }
    }

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                Text("Running Tests...")
            } else {
                ContentView(store: store)
            }
        }
    }
}
