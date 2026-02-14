import Foundation
import Photos

/// Ensures Photos library access is granted before performing operations.
enum PhotosAccess {

    static func ensureAuthorized() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let newStatus = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status)
                }
            }
            switch newStatus {
            case .authorized, .limited:
                return
            case .denied:
                throw PhotosAccessError.accessDenied
            case .notDetermined, .restricted:
                throw PhotosAccessError.accessDenied
            @unknown default:
                throw PhotosAccessError.accessDenied
            }
        case .denied, .restricted:
            throw PhotosAccessError.accessDenied
        @unknown default:
            throw PhotosAccessError.accessDenied
        }
    }
}

enum PhotosAccessError: Error, LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photos library access was denied. Please grant access in System Settings → Privacy & Security → Photos, and ensure the Photos app or this application has permission."
        }
    }
}
