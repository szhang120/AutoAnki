import SwiftUI
import WebKit

/// Stand-alone play view (not used by StudySessionView but kept for parity).
struct FlashcardPlayView: View {
    let deck: Deck
    @EnvironmentObject var deckManager: DeckManager

    @State private var currentIndex = 0
    @State private var showingFront = true
    @State private var sessionComplete = false

    var body: some View {
        VStack(spacing: 16) {

            Text("\(deck.name)   \(currentIndex + 1) / \(deck.cards.count)")
                .font(.headline)
                .padding(.top)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.15))
                // Math-aware flashcard content
                MathTextContainer(content: showingFront 
                                 ? deck.cards[currentIndex].front
                                 : deck.cards[currentIndex].back)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 260)
            .padding(.horizontal, 24)
            .onTapGesture { showingFront.toggle() }

            HStack(spacing: 12) {
                gradeButton("Again", .red,   60)
                gradeButton("Hard",  .orange,360)
                gradeButton("Good",  .green, 600)
                gradeButton("Easy",  .blue,  86_400)
            }
            .padding(.horizontal)

            Spacer()
        }
        .alert("Session complete 🎉", isPresented: $sessionComplete) {
            Button("OK", role: .cancel) {}
        }
        .navigationTitle("Flashcards")
    }

    // MARK: – Helpers
    private func gradeButton(_ title: String, _ color: Color, _ delay: TimeInterval) -> some View {
        Button(title) { nextCard() }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func nextCard() {
        if currentIndex < deck.cards.count - 1 {
            currentIndex += 1
            showingFront = true
        } else {
            sessionComplete = true
        }
    }
}
