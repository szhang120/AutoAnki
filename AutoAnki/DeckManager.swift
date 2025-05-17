//
//  DeckManager.swift
//  AutoAnki
//
//  Created by Sean Zhang on 5/13/25.
//

import Foundation

@MainActor
class DeckManager: ObservableObject {
    @Published var decks: [Deck] = []

    private let fileName = "decks.json"

    private var fileURL: URL {
        let manager = FileManager.default
        let docs = manager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    init() {
        loadDecks()
    }

    func addDeck(name: String) {
        let newDeck = Deck(name: name)
        decks.append(newDeck)
        saveDecks()
    }

    func addCard(to deck: Deck, front: String, back: String) {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[index].cards.append(Card(front: front, back: back))
        saveDecks()
    }

    /// Batch-append multiple cards to the specified deck.
    func addCards(to deck: Deck, cards: [Card]) {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[index].cards.append(contentsOf: cards)
        saveDecks()
    }

    func saveDecks() {
        do {
            let data = try JSONEncoder().encode(decks)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save decks: \(error)")
        }
    }

    func loadDecks() {
        do {
            let data = try Data(contentsOf: fileURL)
            decks = try JSONDecoder().decode([Deck].self, from: data)
        } catch {
            print("No saved decks found or failed to load: \(error)")
        }
    }

    /// Update the given card's front/back within a deck.
    func updateCard(in deck: Deck, cardID: UUID, newFront: String, newBack: String) {
        guard let deckIdx = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        guard let cardIdx = decks[deckIdx].cards.firstIndex(where: { $0.id == cardID }) else { return }
        decks[deckIdx].cards[cardIdx].front = newFront
        decks[deckIdx].cards[cardIdx].back  = newBack
        saveDecks()
    }
}
