import SwiftUI
import SystemExtensions

struct ContentView: View {
    
    let extentionID: String = "tokyo.shmdevelopment.MyCreativeCamera.Extension"

    var body: some View {
        HStack {
            Button {
                let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extentionID, queue: .main)
                OSSystemExtensionManager.shared.submitRequest(activationRequest)
            } label: {
                Text("Install")
            }
            Button {
                let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extentionID, queue: .main)
                OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
            } label: {
                Text("Uninstall")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
