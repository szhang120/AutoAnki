//
//  Card.swift
//  AutoAnki
//
//  Created by Sean Zhang on 5/13/25.
//

import Foundation

struct Card: Identifiable, Codable {
    let id: UUID
    var front: String
    var back: String

    init(id: UUID = UUID(), front: String, back: String) {
        self.id = id
        self.front = front
        self.back = back
    }
}

import Foundation

struct Deck: Identifiable, Codable {
    let id: UUID
    var name: String
    var cards: [Card]

    init(id: UUID = UUID(), name: String, cards: [Card] = []) {
        self.id = id
        self.name = name
        self.cards = cards
    }
}


