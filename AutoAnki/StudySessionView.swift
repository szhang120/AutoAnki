import SwiftUI
import WebKit
import Combine

/// Tab-based study session: **Card** tab for review + **GPT** chat tab.
struct StudySessionView: View {
    let deckID: UUID
    @EnvironmentObject var deckManager: DeckManager
    @State private var deck: Deck

    // Card state
    @State private var currentIndex = 0
    @State private var showingFront = true

    // Alert when deck is finished
    @State private var sessionComplete = false
    
    // For notification handling
    @State private var notificationToken: AnyCancellable?

    init(deck: Deck) {
        self.deckID = deck.id
        _deck = State(initialValue: deck)
    }

    // MARK: – Computed helpers
    private var currentCard: Card { deck.cards[currentIndex] }
    private var progressText: String { "\(deck.name)   \(currentIndex + 1) / \(deck.cards.count)" }

    // MARK: – Body
    var body: some View {
        TabView {
            cardTab
                .tabItem { Label("Card", systemImage: "rectangle.on.rectangle") }

            GPTView(card: currentCard)
                .environmentObject(deckManager)
                .tabItem { Label("GPT", systemImage: "brain.head.profile") }
        }
        .navigationTitle("Study Mode")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Session complete 🎉", isPresented: $sessionComplete) {
            Button("OK", role: .cancel) { }
        }

        // Sync deck when deckManager updates
        .onReceive(deckManager.$decks) { _ in
            if let updated = deckManager.decks.first(where: { $0.id == deckID }) {
                self.deck = updated
            }
        }
        // Listen for card updates from GPTView integration
        .onAppear {
            self.notificationToken = NotificationCenter.default
                .publisher(for: NSNotification.Name("CardUpdated"))
                .sink { notification in
                    if let cardID = notification.userInfo?["cardID"] as? UUID, 
                       cardID == currentCard.id,
                       let updatedDeck = deckManager.decks.first(where: { $0.id == deckID }) {
                        // Update the deck with the latest data from deck manager
                        self.deck = updatedDeck
                    }
                }
        }
        .onDisappear {
            notificationToken?.cancel()
        }
    }

    // MARK: – Card tab view
    private var cardTab: some View {
        VStack(spacing: 16) {

            // Progress
            Text(progressText)
                .font(.headline)
                .padding(.top)

            Spacer()

            // Flashcard panel
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.15))
                    .shadow(radius: 4)

                // Math-aware flashcard content
                MathTextContainer(content: showingFront ? currentCard.front : currentCard.back)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 260)
            .padding(.horizontal, 24)
            .onTapGesture { showingFront.toggle() }
            .gesture(DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 { nextCard() }
                    if value.translation.width >  40 { prevCard() }
                })

            // Grading buttons
            HStack(spacing: 12) {
                gradeButton(.again)
                gradeButton(.hard)
                gradeButton(.good)
                gradeButton(.easy)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom)
    }

    // MARK: – Grading helpers
    private enum Grade: String { case again, hard, good, easy
        var title: String { switch self {
            case .again: "Again"
            case .hard : "Hard"
            case .good : "Good"
            case .easy : "Easy" } }
        var color: Color { switch self {
            case .again: .red
            case .hard : .orange
            case .good : .green
            case .easy : .blue } }
        var delay: TimeInterval { switch self {
            case .again:   60       // 1 min
            case .hard :  360       // 6 min
            case .good :  600       // 10 min
            case .easy : 86400 } }  // 1 day
    }

    @ViewBuilder
    private func gradeButton(_ grade: Grade) -> some View {
        Button(grade.title) { self.grade(grade) }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(grade.color.opacity(0.15))
            .foregroundColor(grade.color)
            .clipShape(Capsule())
            // add per-button 1/2/3/4 shortcuts:
            .keyboardShortcut(KeyEquivalent(grade.rawValue.first!), modifiers: [])
    }

    private func grade(_ grade: Grade) {
        // TODO: Persist `grade.delay` for real spaced-repetition
        nextCard()
    }

    // MARK: – Card navigation
    private func nextCard() {
        guard currentIndex < deck.cards.count - 1 else {
            sessionComplete = true
            return
        }
        currentIndex += 1
        showingFront = true
    }

    private func prevCard() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        showingFront = true
    }
}
