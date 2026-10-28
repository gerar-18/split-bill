import SwiftUI

struct ContentView: View {
    @State private var viewModel = ReceiptEditorViewModel()

    var body: some View {
        ReceiptWorkspaceView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
