import SwiftUI

struct ContentView: View {
    @State private var viewModel: ReceiptEditorViewModel
    @State private var collaborationViewModel = SharedSessionViewModel()

    init(store: (any ReceiptPersistenceStore)? = nil) {
        _viewModel = State(initialValue: ReceiptEditorViewModel(store: store))
    }

    var body: some View {
        ReceiptWorkspaceView(
            viewModel: viewModel,
            collaborationViewModel: collaborationViewModel
        )
        .onOpenURL { url in
            collaborationViewModel.handleIncomingURL(url)
        }
    }
}

#Preview {
    ContentView()
}
