import SwiftUI
import SystemExtensions
import Defaults

struct ContentView: View {

    @Default(.message) var message

    var viewModel: ViewModel = ViewModel()

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

                VStack {
                    Button {
                        viewModel.startSpeechRecognize()
                    } label: {
                        Text("Recognize: Start")
                    }
                    Button {
                        viewModel.stopSpeechRecognize()
                    } label: {
                        Text("Recognize: Stop")
                    }
                }
            }
            .padding()
        }.onAppear {
            viewModel.setUpSpeechRecognizer()
        }
    }
}

#Preview {
    ContentView()
}

class ViewModel: NSObject, ObservableObject, SpeechRecognizerDelegate {

    @Default(.message) var message: String

    let speechRecognizer = SpeechRecognizer()

    func setUpSpeechRecognizer() {
        speechRecognizer.setup(delegate: self)
    }

    func startSpeechRecognize() {
        guard !speechRecognizer.started else { return }
        speechRecognizer.start()
    }

    func stopSpeechRecognize() {
        speechRecognizer.stop()
    }

    func speechTextUpdate(value: String) {
        message = value
    }
}
