//  CardGenerator.swift
//  AutoAnki
//  Generates flashcards from raw text using GPT function-calling.

import Foundation

@MainActor
final class CardGenerator {

    static let shared = CardGenerator()
    private init() {}

    /// Generates cards from raw text using the `extract_cards_from_text` function schema.
    /// - Parameter text: Raw study notes or extracted PDF text.
    /// - Returns: Array of freshly generated `Card`s (may be empty on failure).
    func generateCards(from text: String) async -> [Card] {
        guard let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            print("⚠️ Missing API key in Info.plist")
            return []
        }

        // --- 1. Build the function schema ----------------------------------
        let functionSchema: [String: Any] = [
            "name": "extract_cards_from_text",
            "description": "Generate Anki flashcards from raw input text.",
            "parameters": [
                "type": "object",
                "properties": [
                    "cards": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "front": ["type": "string"],
                                "back":  ["type": "string"]
                            ],
                            "required": ["front", "back"]
                        ]
                    ]
                ],
                "required": ["cards"]
            ]
        ]

        // --- 2. Compose chat messages ---------------------------------------
        let systemPrompt = "You are an expert flashcard generator. Follow Anki best-practices. Return JSON matching the function schema when invoked."
        let userPrompt   = "Generate high-quality flashcards from the following text:\n\n" + text

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user",   "content": userPrompt]
        ]

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "functions": [functionSchema],
            "function_call": ["name": "extract_cards_from_text"]
        ]

        // --- 3. Perform request ---------------------------------------------
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do { req.httpBody = try JSONSerialization.data(withJSONObject: body) } catch {
            print("⚠️ Failed to encode request body: \(error)"); return [] }

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any]
            else { return [] }

            // Prefer structured tool call result
            if let functionCall = message["function_call"] as? [String: Any],
               let argumentsRaw = functionCall["arguments"] as? String,
               let argumentsData = argumentsRaw.data(using: .utf8),
               let argsJSON  = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any],
               let cardDicts = argsJSON["cards"] as? [[String: String]] {
                return cardDicts.compactMap { dict in
                    guard let f = dict["front"], let b = dict["back"] else { return nil }
                    return Card(front: f, back: b)
                }
            }

            // Fallback: try plain-text JSON in content
            if let content = message["content"] as? String,
               let data = content.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                return array.compactMap { dict in
                    guard let f = dict["front"], let b = dict["back"] else { return nil }
                    return Card(front: f, back: b)
                }
            }
        } catch {
            print("⚠️ Card generation network/parsing error: \(error)")
        }

        return []
    }
}

extension Card: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Card, rhs: Card) -> Bool { lhs.id == rhs.id }
}

// End of file 