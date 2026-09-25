import Foundation

/// Eight unbiased symbols provide 40 bits of OS-backed randomness. Codes are
/// stable for the room lifetime, separate from authentication/resume credentials.
enum RoomCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        var random = SystemRandomNumberGenerator()
        return String((0..<8).map { _ in alphabet[Int.random(in: alphabet.indices, using: &random)] })
    }

    static func isValid(_ code: String) -> Bool {
        code.utf8.count == 8 && code.allSatisfy { alphabet.contains($0) }
    }
}
