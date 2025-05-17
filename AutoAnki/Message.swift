import Foundation

/// Generic chat message used by GPTView.
struct Message: Identifiable {
    let id = UUID()
    let role: String        // "system", "user", or "assistant"
    let content: String
}
