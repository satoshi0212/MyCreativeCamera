import Foundation
import CoreMediaIO
import IOKit.audio
import os.log
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Defaults

let kFrameRate: Int = 60

// MARK: -

class ExtensionDeviceSource: NSObject, CMIOExtensionDeviceSource {
	
	private(set) var device: CMIOExtensionDevice!
	private var _streamSource: ExtensionStreamSource!
	private var _videoDescription: CMFormatDescription!
	private var _bufferPool: CVPixelBufferPool!
	private var _bufferAuxAttributes: NSDictionary!

    private let ciContext = CIContext()
    private let filterComposite = CIFilter(name: "CISourceOverCompositing")
    private var textImage: CIImage?

    private var isBypass: Bool = false

    let input: AVCaptureDeviceInput = {
        let device = AVCaptureDevice.DiscoverySession.faceTimeDevice()
        return try! AVCaptureDeviceInput(device: device)
    }()

    let output: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA
        ]
        return output
    }()

    lazy var session: AVCaptureSession = {
        var session = AVCaptureSession()
        session.addInput(input)
        output.setSampleBufferDelegate(self, queue: .main)
        session.addOutput(output)
        return session
    }()

	init(localizedName: String) {
		
		super.init()
		let deviceID = UUID() // replace this with your device UUID
		self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: nil, source: self)
		
		let dims = CMVideoDimensions(width: 1920, height: 1080)
		CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
		
		let pixelBufferAttributes: NSDictionary = [
			kCVPixelBufferWidthKey: dims.width,
			kCVPixelBufferHeightKey: dims.height,
			kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
			kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary
		]
		CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
		
		let videoStreamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
		_bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
		
		let videoID = UUID() // replace this with your video UUID
		_streamSource = ExtensionStreamSource(localizedName: "MyCreativeCamera.Video", streamID: videoID, streamFormat: videoStreamFormat, device: device)
		do {
			try device.addStream(_streamSource.stream)
		} catch let error {
			fatalError("Failed to add stream: \(error.localizedDescription)")
		}

        observeSettings()
	}
	
	var availableProperties: Set<CMIOExtensionProperty> {
		
		return [.deviceTransportType, .deviceModel]
	}
	
	func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
		
		let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
		if properties.contains(.deviceTransportType) {
			deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
		}
		if properties.contains(.deviceModel) {
			deviceProperties.model = "MyCreativeCamera Model"
		}
		
		return deviceProperties
	}
	
	func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
		
		// Handle settable properties here.
	}
	
    func startStreaming() {
        session.startRunning()
    }

    func stopStreaming() {
        session.stopRunning()
    }

    private func observeSettings() {
        Task {
            for await isBypass in Defaults.updates(.isBypass) {
                self.isBypass = isBypass
            }
        }

        Task {
            for await message in Defaults.updates(.message) {
                textImage = Utility.generate(text: message)
            }
        }
    }
}

// MARK: -

class ExtensionStreamSource: NSObject, CMIOExtensionStreamSource {
	
	private(set) var stream: CMIOExtensionStream!
	
	let device: CMIOExtensionDevice
	
	private let _streamFormat: CMIOExtensionStreamFormat
	
	init(localizedName: String, streamID: UUID, streamFormat: CMIOExtensionStreamFormat, device: CMIOExtensionDevice) {
		
		self.device = device
		self._streamFormat = streamFormat
		super.init()
		self.stream = CMIOExtensionStream(localizedName: localizedName, streamID: streamID, direction: .source, clockType: .hostTime, source: self)
	}
	
	var formats: [CMIOExtensionStreamFormat] {
		
		return [_streamFormat]
	}
	
	var activeFormatIndex: Int = 0 {
		
		didSet {
			if activeFormatIndex >= 1 {
				os_log(.error, "Invalid index")
			}
		}
	}
	
	var availableProperties: Set<CMIOExtensionProperty> {
		
		return [.streamActiveFormatIndex, .streamFrameDuration]
	}
	
	func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
		
		let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
		if properties.contains(.streamActiveFormatIndex) {
			streamProperties.activeFormatIndex = 0
		}
		if properties.contains(.streamFrameDuration) {
			let frameDuration = CMTime(value: 1, timescale: Int32(kFrameRate))
			streamProperties.frameDuration = frameDuration
		}
		
		return streamProperties
	}
	
	func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
		
		if let activeFormatIndex = streamProperties.activeFormatIndex {
			self.activeFormatIndex = activeFormatIndex
		}
	}
	
	func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
		
		// An opportunity to inspect the client info and decide if it should be allowed to start the stream.
		return true
	}
	
	func startStream() throws {
		
		guard let deviceSource = device.source as? ExtensionDeviceSource else {
			fatalError("Unexpected source type \(String(describing: device.source))")
		}
		deviceSource.startStreaming()
	}
	
	func stopStream() throws {
		
		guard let deviceSource = device.source as? ExtensionDeviceSource else {
			fatalError("Unexpected source type \(String(describing: device.source))")
		}
		deviceSource.stopStreaming()
	}
}

// MARK: -

class ExtensionProviderSource: NSObject, CMIOExtensionProviderSource {
	
	private(set) var provider: CMIOExtensionProvider!
	
	private var deviceSource: ExtensionDeviceSource!
	
	// CMIOExtensionProviderSource protocol methods (all are required)
	
	init(clientQueue: DispatchQueue?) {
		
		super.init()
		
		provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
		deviceSource = ExtensionDeviceSource(localizedName: "MyCreativeCamera")

		do {
			try provider.addDevice(deviceSource.device)
		} catch let error {
			fatalError("Failed to add device: \(error.localizedDescription)")
		}
	}
	
	func connect(to client: CMIOExtensionClient) throws {
		
		// Handle client connect
	}
	
	func disconnect(from client: CMIOExtensionClient) {
		
		// Handle client disconnect
	}
	
	var availableProperties: Set<CMIOExtensionProperty> {
		
		// See full list of CMIOExtensionProperty choices in CMIOExtensionProperties.h
		return [.providerManufacturer]
	}
	
	func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
		
		let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
		if properties.contains(.providerManufacturer) {
			providerProperties.manufacturer = "MyCreativeCamera Manufacturer"
		}
		return providerProperties
	}
	
	func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
		
		// Handle settable properties here.
	}
}

extension ExtensionDeviceSource: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isBypass {
            _streamSource.stream.send(sampleBuffer, discontinuity: .time, hostTimeInNanoseconds: 0)
            return
        }

        let inputImage = CIImage(cvImageBuffer: sampleBuffer.imageBuffer!)

        if let compositedImage = compose(bgImage: inputImage, overlayImage: textImage) {
            ciContext.render(compositedImage, to: sampleBuffer.imageBuffer!)
        }

        _streamSource.stream.send(sampleBuffer, discontinuity: .time, hostTimeInNanoseconds: 0)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        _streamSource.stream.send(sampleBuffer, discontinuity: .sampleDropped, hostTimeInNanoseconds: 0)
    }

    private func compose(bgImage: CIImage, overlayImage: CIImage?) -> CIImage? {
        guard let filterComposite = filterComposite, let overlayImage = overlayImage else {
            return bgImage
        }
        filterComposite.setValue(overlayImage, forKeyPath: kCIInputImageKey)
        filterComposite.setValue(bgImage, forKeyPath: kCIInputBackgroundImageKey)
        return filterComposite.outputImage
    }
}

extension AVCaptureDevice.DiscoverySession {

    static func faceTimeDevice() -> AVCaptureDevice {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        let devices = discoverySession.devices
        let device = devices.filter({ $0.manufacturer == "Apple Inc." && $0.modelID.hasPrefix("FaceTime ")}).first!
        return device
    }
}
