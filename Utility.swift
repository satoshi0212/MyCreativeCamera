import Cocoa

class Utility: NSObject {

    static func generate(text: String, size: CGFloat = 100, imageSize: NSSize = NSSize(width: 1920, height: 1080)) -> CIImage? {
        let font = NSFont(name: "HiraginoSans-W9", size: size) ?? NSFont.systemFont(ofSize: size)

        let image = NSImage(size: imageSize, flipped: false) { (rect) -> Bool in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byCharWrapping

            let numberOfLines: CGFloat = CGFloat(text.split(separator: "\n").count)
            let rectangle = NSRect(x: 0, y: imageSize.height - font.lineHeight() * numberOfLines, width: imageSize.width, height: font.lineHeight() * numberOfLines)
            let textAttributes = [
                .strokeColor: NSColor.black,
                .foregroundColor: NSColor.white,
                .strokeWidth: -1,
                .font: font,
                .paragraphStyle: paragraphStyle
                ] as [NSAttributedString.Key : Any]
            (text as NSString).draw(in: rectangle, withAttributes: textAttributes)
            return true
        }

        return image.ciImage
    }
}

extension NSFont {

    func lineHeight() -> CGFloat {
        return CGFloat(ceilf(Float(ascender + descender + leading)))
    }
}

extension NSImage {

    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
            ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }
        return nil
    }

    var ciImage: CIImage? {
        let newImage = self.resized(to: size)!
        guard let data = newImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return CIImage(bitmapImageRep: bitmap)
    }
}
