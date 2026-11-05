import Foundation

/// Six character join codes without look-alike characters (no 0/O, 1/I).
enum GameCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 6

    static func generate() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// Uppercases and strips spaces and dashes so "abc 123" matches "ABC123".
    static func normalize(_ input: String) -> String {
        input.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy(alphabet.contains)
    }
}
