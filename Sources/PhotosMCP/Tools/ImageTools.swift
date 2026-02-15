import Foundation
import MCP
import Photos

enum ImageTools {

    static func getPhotoThumbnail(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let assetId = String(arguments?["asset_identifier"] ?? .string(""), strict: false), !assetId.isEmpty else {
            return .init(content: [.text("Error: asset_identifier is required")], isError: true)
        }
        let maxDimension = Int(arguments?["max_dimension"] ?? 512, strict: false) ?? 512
        let quality = CGFloat(Double(arguments?["quality"] ?? 0.8, strict: false) ?? 0.8)

        return await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return CallTool.Result(content: [.text("Error: Asset not found with identifier \(assetId)")], isError: true)
            }

            guard asset.mediaType == .image else {
                return CallTool.Result(content: [.text("Error: Asset is not a photo (media type: \(asset.mediaType.rawValue))")], isError: true)
            }

            do {
                let imageData = try await ImageExport.thumbnail(asset: asset, maxDimension: maxDimension, quality: quality)
                let (filePath, _) = saveToTempFile(imageData, prefix: "photo_thumb")
                let w = min(asset.pixelWidth, maxDimension)
                let h = min(asset.pixelHeight, maxDimension)
                let msg: String
                if let path = filePath {
                    msg = "Thumbnail \(w)×\(h) saved. To view: `open \(path)`"
                } else {
                    msg = "Thumbnail \(w)×\(h) (save failed)"
                }
                return CallTool.Result(content: [.text(msg)], isError: false)
            } catch {
                return CallTool.Result(
                    content: [.text("Error: Failed to export thumbnail: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }.value
    }

    static func getPhotoFull(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let assetId = String(arguments?["asset_identifier"] ?? .string(""), strict: false), !assetId.isEmpty else {
            return .init(content: [.text("Error: asset_identifier is required")], isError: true)
        }
        let maxDimension = arguments?["max_dimension"].flatMap { Int($0, strict: false) }
        let quality = CGFloat(Double(arguments?["quality"] ?? 0.8, strict: false) ?? 0.8)

        return await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return CallTool.Result(content: [.text("Error: Asset not found with identifier \(assetId)")], isError: true)
            }

            guard asset.mediaType == .image else {
                return CallTool.Result(content: [.text("Error: Asset is not a photo (media type: \(asset.mediaType.rawValue))")], isError: true)
            }

            var warning: String?
            if maxDimension == nil && (asset.pixelWidth > 4000 || asset.pixelHeight > 4000) {
                warning = "Warning: Full-resolution image is large (\(asset.pixelWidth)x\(asset.pixelHeight)). Consider max_dimension (e.g. 2048) to downscale."
            }

            do {
                let imageData = try await ImageExport.fullImage(
                    asset: asset,
                    maxDimension: maxDimension,
                    quality: quality
                )
                let outW = maxDimension.map { min(asset.pixelWidth, $0) } ?? asset.pixelWidth
                let outH = maxDimension.map { min(asset.pixelHeight, $0) } ?? asset.pixelHeight
                let (filePath, _) = saveToTempFile(imageData, prefix: "photo_full")
                var parts: [String] = []
                if let w = warning { parts.append(w) }
                parts.append("Image \(outW)×\(outH), \(imageData.count) bytes.")
                if let path = filePath {
                    parts.append("To view: `open \(path)`")
                }
                return CallTool.Result(content: [.text(parts.joined(separator: " "))], isError: false)
            } catch {
                return CallTool.Result(
                    content: [.text("Error: Failed to export image: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }.value
    }
}

private let tempFilesSubdirName = "PhotosMCP"

private func saveToTempFile(_ data: Data, prefix: String) -> (path: String?, displayPath: String?) {
    let fm = FileManager.default
    let tmpDir = fm.temporaryDirectory.appendingPathComponent(tempFilesSubdirName, isDirectory: true)
    let baseDir: URL
    if (try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)) != nil {
        baseDir = tmpDir
        TempFileCleanup.cleanStaleFiles(in: tmpDir)
    } else {
        baseDir = fm.temporaryDirectory
    }

    let name = "\(prefix)_\(UUID().uuidString.prefix(8)).jpg"
    let fileURL = baseDir.appendingPathComponent(name)
    do {
        try data.write(to: fileURL)
        return (fileURL.path, fileURL.path)
    } catch {
        return (nil, nil)
    }
}

/// Cleans exported image temp files older than 1 hour to limit disk use and exposure window.
enum TempFileCleanup {
    private static let maxAgeSeconds: TimeInterval = 3600  // 1 hour

    static func cleanStaleFiles(in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-maxAgeSeconds)
        for url in contents where url.pathExtension == "jpg" {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let creation = attrs[.creationDate] as? Date,
                  creation < cutoff else { continue }
            try? fm.removeItem(at: url)
        }
    }
}
