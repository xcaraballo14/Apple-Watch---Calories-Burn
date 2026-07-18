import CoreGraphics
import ImageIO
import SensitiveContentAnalysis
import UIKit
import UniformTypeIdentifiers

/// Everything a photo goes through between "the player picked it" and "it
/// leaves the device". Every step here is load-bearing; none of it is
/// optional polish.
///
/// **The metadata problem.** A photo straight out of the camera carries EXIF:
/// GPS coordinates, capture timestamp, device identity. Uploading the original
/// file would publish the exact spot a selfie was taken — someone's home —
/// which flatly contradicts BurnReward's privacy promise, and would do it
/// invisibly, since nothing on screen would look wrong. So we never upload the
/// bytes we were handed. `prepare` re-renders the picked image into fresh JPEG
/// data through a bitmap context, which cannot carry metadata forward: the
/// only thing that survives is pixels.
enum PostPhotoPipeline {
    /// Long edge after downscaling. 1440 stays sharp on a 3x phone while
    /// keeping a post's egress cost sane (photos, not the feed rows, are what
    /// drives the Supabase bill).
    static let maxDimension: CGFloat = 1440
    static let jpegQuality: CGFloat = 0.75
    static let bucket = "post-photos"

    enum PhotoError: LocalizedError {
        case sensitiveContent
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .sensitiveContent:
                "That photo looks like it may contain nudity, so it can't be posted."
            case .encodingFailed:
                "That photo couldn't be prepared for sharing."
            }
        }
    }

    /// Downscale → re-encode (dropping all metadata) → screen for explicit
    /// content. Returns upload-ready JPEG bytes.
    ///
    /// Order matters: the analysis runs on the prepared image so we're
    /// screening exactly what would ship, and it runs entirely on-device —
    /// nothing is sent anywhere to be checked.
    static func prepare(_ image: UIImage) async throws -> Data {
        let resized = downscale(image)
        guard let data = encodeStrippingMetadata(resized) else {
            throw PhotoError.encodingFailed
        }
        if try await isSensitive(data) {
            throw PhotoError.sensitiveContent
        }
        return data
    }

    /// Aspect-preserving downscale. Images already smaller than the ceiling are
    /// still redrawn — the re-render is what strips metadata, so it must not be
    /// skipped as an "optimization".
    private static func downscale(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // target is already in pixels
        format.opaque = true      // JPEG has no alpha; opaque avoids a wasted pass
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Writes JPEG bytes with an explicitly empty metadata dictionary. Belt and
    /// braces: the redraw above already discarded EXIF, and this guarantees
    /// nothing is re-attached on the way out.
    private static func encodeStrippingMetadata(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality,
            // Empty dictionaries where GPS/EXIF would otherwise live.
            kCGImagePropertyExifDictionary: [:] as CFDictionary,
            kCGImagePropertyGPSDictionary: [:] as CFDictionary,
            kCGImagePropertyTIFFDictionary: [:] as CFDictionary,
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// On-device nudity screening (iOS 17+). Returns false when the user hasn't
    /// enabled Sensitive Content Warning — the analyser is unavailable, not
    /// permissive, and the report/block flow is what covers the rest. We never
    /// block a post because analysis merely failed.
    private static func isSensitive(_ data: Data) async throws -> Bool {
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else { return false }
        guard let image = UIImage(data: data)?.cgImage else { return false }
        do {
            return try await analyzer.analyzeImage(image).isSensitive
        } catch {
            return false
        }
    }

    /// `<user_id>/<event_id>/<n>.jpg` — the first segment is what the storage
    /// policies in p2_schema.sql key ownership off, so this shape is part of
    /// the security model, not a naming convenience.
    static func path(user: UUID, event: UUID, index: Int) -> String {
        "\(user.uuidString)/\(event.uuidString)/\(index).jpg"
    }
}

/// Small in-memory cache so scrolling the feed doesn't re-download the same
/// photo. Private-bucket reads are authorized per request, so nothing here can
/// widen who sees what — it only avoids repeating a fetch the user already
/// made. Cleared on sign-out along with the rest of the social state.
@MainActor
final class PostPhotoCache {
    static let shared = PostPhotoCache()
    private var images: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {}

    func image(at path: String) -> UIImage? { images[path] }

    func load(_ path: String) async -> UIImage? {
        if let cached = images[path] { return cached }
        if let existing = inFlight[path] { return await existing.value }

        let task = Task<UIImage?, Never> {
            let data = try? await SupabaseAPI.shared.download(
                bucket: PostPhotoPipeline.bucket, path: path
            )
            return data.flatMap(UIImage.init(data:))
        }
        inFlight[path] = task
        let image = await task.value
        inFlight[path] = nil
        if let image { images[path] = image }
        return image
    }

    func clear() {
        images.removeAll()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
    }
}
