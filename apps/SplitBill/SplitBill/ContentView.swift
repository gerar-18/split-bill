import SwiftUI

struct ContentView: View {
    @State private var viewModel: ReceiptEditorViewModel

    init(store: (any ReceiptPersistenceStore)? = nil) {
        _viewModel = State(initialValue: ReceiptEditorViewModel(store: store))
    }

    var body: some View {
        ReceiptWorkspaceView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
