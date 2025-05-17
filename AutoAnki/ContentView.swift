//
//  ContentView.swift
//  AutoAnki
//
//  Created by Sean Zhang on 5/13/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var deckManager = DeckManager()
    @State private var newDeckName = ""

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("New Deck Name", text: $newDeckName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        guard !newDeckName.isEmpty else { return }
                        deckManager.addDeck(name: newDeckName)
                        newDeckName = ""
                    }
                }
                .padding()

                List {
                    ForEach(deckManager.decks) { deck in
                        NavigationLink(destination: DeckDetailView(deck: deck)
                                        .environmentObject(deckManager)) {
                            Text(deck.name)
                        }
                    }
                }
                .refreshable {
                    deckManager.loadDecks()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { deckManager.loadDecks() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("My Decks")
        }
    }
}
