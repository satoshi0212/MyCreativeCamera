import SwiftUI
import SystemExtensions
import Defaults

struct ContentView: View {

    @Default(.message) var message

    var body: some View {
        VStack {
            HStack {
                Button {
                    let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
                    OSSystemExtensionManager.shared.submitRequest(activationRequest)
                } label: {
                    Text("Install")
                }
                Button {
                    let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
                    OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
                } label: {
                    Text("Uninstall")
                }
                Defaults.Toggle("Bypass", key: .isBypass)
            }
            .padding()

            HStack {
                TextEditor(text: $message)
                    .font(.system(size: 16))
                    .border(Color.gray, width: 1)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
