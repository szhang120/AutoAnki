//
//  DeckDetailView.swift
//  AutoAnki
//
//  Created by Sean Zhang on 5/13/25.
//

import SwiftUI

struct DeckDetailView: View {
    @EnvironmentObject var deckManager: DeckManager
    let deck: Deck

    @State private var front = ""
    @State private var back = ""

    var body: some View {
        VStack {
            HStack {
                TextField("Front", text: $front)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Back", text: $back)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add Card") {
                    guard !front.isEmpty && !back.isEmpty else { return }
                    deckManager.addCard(to: deck, front: front, back: back)
                    front = ""
                    back = ""
                }
            }
            .padding()
            
            NavigationLink(destination: StudySessionView(deck: deck)
                .environmentObject(deckManager)
            ) {
                Text("Study Deck")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }

            // New card-generation entry point
            NavigationLink(destination: CardGenerationView(deck: deck).environmentObject(deckManager)) {
                Text("Generate Cards from Text/PDF")
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            List {
                ForEach(deck.cards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Q:")
                                .bold()
                                .font(.callout)
                            MathTextContainer(content: card.front)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("A:")
                                .foregroundColor(.secondary)
                                .font(.callout)
                            MathTextContainer(content: card.back)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(deck.name)
    }
}

