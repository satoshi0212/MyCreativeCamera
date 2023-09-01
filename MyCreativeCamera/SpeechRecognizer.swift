import AVFoundation
import Speech

public protocol SpeechRecognizerDelegate {
    func speechTextUpdate(value: String)
}

public class SpeechRecognizer {
    public var started = false
    private var delegate: SpeechRecognizerDelegate?

    private var recognizer: SFSpeechRecognizer!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    private var recognitionTask: SFSpeechRecognitionTask!
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?

    private var previousResult: SFSpeechRecognitionResult?

    public init() { }

    public func setup(delegate: SpeechRecognizerDelegate) {

        self.delegate = delegate

        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
               switch authStatus {
                   case .authorized:
                       print("authorized")
                   case .denied:
                       print("denied")
                   case .restricted:
                       print("restricted")
                   case .notDetermined:
                       print("not determined")
                   @unknown default:
                       fatalError()
               }
           }
        }

        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    }

    public func start() {
        inputNode = startAudio()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        startRecognitionTask()
        started = true
    }

    public func stop() {
        audioEngine.stop()

        if let node = inputNode {
            node.removeTap(onBus: 0)
            node.reset()
        }

        if let request = recognitionRequest {
            request.endAudio()
        }
        recognitionRequest = nil

        if let task = recognitionTask {
            task.finish()
        }
        recognitionTask = nil

        started = false
    }

    private func startAudio() -> AVAudioInputNode {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) -> Void in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("audio started")
        } catch {
            print("AVAudioEngine error: \(error)")
        }

        return inputNode
    }

    private func startRecognitionTask() {
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let foundResult = result {
                self.previousResult = foundResult
                isFinal = foundResult.isFinal
                print(foundResult.bestTranscription.formattedString)
                self.delegate?.speechTextUpdate(value: foundResult.bestTranscription.formattedString)
            }

            if error != nil {
                print("\(error!.localizedDescription)")
                self.stop()
            }

            if isFinal {
                print("FINAL RESULT reached")
                self.stop()
            }
        }
    }
}
