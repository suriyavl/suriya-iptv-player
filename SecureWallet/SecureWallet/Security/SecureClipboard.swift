import UIKit
import UniformTypeIdentifiers

/// Copies public data (addresses, tx hashes) to the clipboard so that it is
/// never shared with other devices through Universal Clipboard and expires
/// after a short time. Secrets are never copied.
enum SecureClipboard {
    static func copy(_ string: String, expiresIn seconds: TimeInterval = 60) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: string]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(seconds),
            ]
        )
    }
}
