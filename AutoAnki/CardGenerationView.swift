//  CardGenerationView.swift
//  AutoAnki

import SwiftUI

/// View allowing the user to paste raw notes and generate flashcards via GPT.
struct CardGenerationView: View {

    @EnvironmentObject var deckManager: DeckManager
    let deck: Deck

    @State private var rawInput: String = ""
    @State private var isLoading = false
    @State private var generated: [Card] = []
    @State private var errorMsg: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste text from notes or a PDF. The assistant will generate flashcards you can preview and save.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $rawInput)
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    .padding(.horizontal)

                HStack {
                    Spacer()
                    Button(isLoading ? "Generating…" : "Generate Cards") {
                        Task { await generate() }
                    }
                    .disabled(rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }

                if !generated.isEmpty {
                    Text("Preview (\(generated.count)) cards")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(generated) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q: \(card.front)").bold()
                            Text("A: \(card.back)").foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
                    }

                    HStack {
                        Spacer()
                        Button("Add All to Deck") {
                            deckManager.addCards(to: deck, cards: generated)
                            generated.removeAll()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    .padding(.top)
                }

                if let errorMsg {
                    Text(errorMsg).foregroundColor(.red).padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Generate Cards")
    }

    @MainActor
    private func generate() async {
        errorMsg = nil
        isLoading = true
        generated = await CardGenerator.shared.generateCards(from: rawInput)
        isLoading = false
        if generated.isEmpty { errorMsg = "No cards were generated." }
    }
}

// End of file 