import SwiftUI
import WebKit

/// Multi-turn chat with GPT where the current card's front and back are silently
/// supplied as context. Each user query automatically includes both sides.
struct GPTView: View {
    let card: Card

    @EnvironmentObject var deckManager: DeckManager

    @State private var messages: [Message] = []
    @State private var userInput: String = ""
    @State private var isLoading = false

    // Integrate sheet state
    @State private var selectedAssistantMessage: Message? = nil
    @State private var integrateInput: String = ""
    @State private var isIntegrateLoading = false
    @State private var showSuccessToast = false
    @State private var errorMessage: String? = nil
    @State private var showErrorToast = false

    var body: some View {
        VStack(spacing: 0) {
            // ScrollViewReader, chat history, input field, etc.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages.filter { $0.role != "system" }) { msg in
                            ChatBubble(message: msg, onIntegrate: { tappedMsg in
                                if tappedMsg.role == "assistant" {
                                    integrateInput = ""
                                    selectedAssistantMessage = tappedMsg
                                }
                            }).id(msg.id)
                        }
                        if isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { oldValue, newValue in
                    if let lastID = messages.last?.id {
                        // Delay scrolling slightly to allow rendering to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("Ask about this card…", text: $userInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit(send)

                Button("Send", action: send)
                    .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("GPT Help")
        .sheet(item: $selectedAssistantMessage) { assistantMsg in
            VStack(spacing: 16) {
                Text("Integrate into card")
                    .font(.headline)
                ScrollView {
                    MathTextContainer(content: assistantMsg.content)
                        .frame(maxHeight: 300)
                }
                TextEditor(text: $integrateInput)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    .padding(.horizontal)
                    .onAppear { integrateInput = "" }
                    .disabled(isIntegrateLoading)

                if let errorMsg = errorMessage, showErrorToast {
                    Text(errorMsg)
                        .foregroundColor(.red)
                        .font(.callout)
                        .padding(.horizontal)
                }

                HStack {
                    Button("Cancel") { 
                        selectedAssistantMessage = nil 
                    }
                    .disabled(isIntegrateLoading)
                    
                    Spacer()
                    
                    if isIntegrateLoading {
                        ProgressView()
                            .padding(.horizontal)
                    }
                    
                    Button(isIntegrateLoading ? "Processing..." : "Apply") {
                        applyIntegration(message: assistantMsg)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isIntegrateLoading)
                }
                .padding(.horizontal)
            }
            .presentationDetents([.medium, .large])
            .padding()
        }
        .overlay(
            Group {
                if showSuccessToast {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .padding(12)
                        .background(Color.green.opacity(0.9))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
                else if showErrorToast, let errorMsg = errorMessage {
                    Label(errorMsg, systemImage: "exclamationmark.triangle.fill")
                        .padding(12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .transition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                        .multilineTextAlignment(.leading)
                }
            }, alignment: .top
        )
        .onAppear {
            // initial system prompt (once)
            if messages.isEmpty {
                let system = """
                You are a helpful study assistant. The flashcard in context is:

                Front: \(card.front)
                Back: \(card.back)

                Provide clear, concise answers.
                When explaining mathematical concepts or formulas, use LaTeX notation enclosed in $ symbols for inline math or $$ for block display. 
                Examples: Use $x^2$ for squared variables or $$\\frac{a}{b}$$ for fractions on their own line.
                Format mathematical equations using LaTeX syntax and enclose them in $ for inline or $$ for display mode.
                """
                messages.append(Message(role: "system", content: system))
            }
        }
    }

    // MARK: - Chat Actions

    /// Every time the user submits, we wrap their text
    /// with both Front and Back so GPT always sees full context.
    private func send() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // We only display the user question in the chat
        messages.append(Message(role: "user", content: trimmed))
        
        // **PREPEND** the full card (front & back) to the API request message:
        let fullText = """
        Front: \(card.front)
        Back: \(card.back)

        Question: \(trimmed)

        Remember to format any mathematical expressions using LaTeX syntax:
        - Use $...$ for inline math
        - Use $$...$$ for display math
        - Escape special characters properly
        """
        
        userInput = ""
        callGPT(userMessage: fullText)
    }

    private func callGPT(userMessage: String, retryCount: Int = 0) {
        isLoading = true

        guard let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            messages.append(Message(role: "assistant", content: "⚠️ Missing API key."))
            isLoading = false
            return
        }
        
        // Create API messages - we filter out user display messages
        var apiMessages = messages.filter { $0.role == "system" }.map { 
            ["role": $0.role, "content": $0.content] 
        }
        
        // Add the user's message with full context
        apiMessages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": apiMessages,
            "temperature": 0.7
        ]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                messages.append(Message(role: "assistant", content: "⚠️ Error preparing request: \(error.localizedDescription)"))
            }
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            defer { isLoading = false }

            if let error = error {
                if retryCount < 2 {
                    // Retry after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        callGPT(userMessage: userMessage, retryCount: retryCount + 1)
                    }
                } else {
                    DispatchQueue.main.async {
                        messages.append(Message(role: "assistant", content: "⚠️ Network error: \(error.localizedDescription)"))
                    }
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    messages.append(Message(role: "assistant", content: "⚠️ No data received"))
                }
                return
            }

            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response: \(jsonString)") // Debug print
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for API error response
                if let error = json?["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    DispatchQueue.main.async {
                        messages.append(Message(role: "assistant", content: "⚠️ API Error: \(message)"))
                    }
                    return
                }
                
                guard let choices = json?["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }

                DispatchQueue.main.async {
                    messages.append(Message(role: "assistant", content: content.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } catch {
                DispatchQueue.main.async {
                    messages.append(Message(role: "assistant", content: "⚠️ Parsing error: \(error.localizedDescription)"))
                }
            }
        }.resume()
    }

    /// Apply integration edits to the underlying card via GPT
    private func applyIntegration(message: Message) {
        // Find prior user query for context
        let priorUserQuery = findPriorUserQuery(for: message)
        
        isIntegrateLoading = true
        
        // Create integration prompt
        let userInstructions = integrateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let integrationPrompt = createIntegrationPrompt(
            front: card.front,
            back: card.back,
            userQuery: priorUserQuery,
            assistantResponse: message.content,
            userInstructions: userInstructions
        )
        
        // Call GPT to refine the card
        callGPTForIntegration(prompt: integrationPrompt) { result in
            self.isIntegrateLoading = false
            
            switch result {
            case .success(let refinedCard):
                // Create a local copy with updated content for the UI
                var updatedCard = self.card
                updatedCard.front = refinedCard.front
                updatedCard.back = refinedCard.back
                
                // Update state for card reflection in the view
                let deck = self.findDeck(for: self.card)
                
                // Update the deck manager
                self.deckManager.updateCard(
                    in: deck,
                    cardID: self.card.id,
                    newFront: refinedCard.front,
                    newBack: refinedCard.back
                )
                
                // Force a UI update by posting a notification
                NotificationCenter.default.post(name: NSNotification.Name("CardUpdated"), object: nil, userInfo: ["cardID": self.card.id])
                
                // Close the sheet and show success
                self.selectedAssistantMessage = nil
                self.showSuccessToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showSuccessToast = false
                }
                
            case .failure(let error):
                // Handle error with UI feedback
                self.errorMessage = "Integration failed: \(error.localizedDescription)"
                self.showErrorToast = true
                
                // Keep sheet open on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showErrorToast = false
                    // Only close sheet after showing the error
                    self.selectedAssistantMessage = nil
                }
            }
        }
    }
    
    /// Find the user query that preceded the given assistant message
    private func findPriorUserQuery(for assistantMessage: Message) -> String {
        guard let assistantIndex = messages.firstIndex(where: { $0.id == assistantMessage.id }) else {
            return ""
        }
        
        // Look backward for the nearest user message
        for i in stride(from: assistantIndex - 1, through: 0, by: -1) {
            if messages[i].role == "user" {
                return messages[i].content
            }
        }
        
        return ""
    }
    
    /// Create a prompt to guide GPT in integrating the information
    private func createIntegrationPrompt(
        front: String,
        back: String,
        userQuery: String,
        assistantResponse: String,
        userInstructions: String
    ) -> String {
        let basePrompt = """
        Your task is to refine a flashcard by integrating new information.
        
        # ORIGINAL FLASHCARD
        Front: \(front)
        Back: \(back)
        
        # CONTEXT
        User question: \(userQuery)
        Assistant response: \(assistantResponse)
        
        # INSTRUCTIONS
        - By default, only ADD information to the card (do not remove existing information)
        - Preserve all existing information in both sides of the card
        - Ensure all mathematical notation is properly formatted with LaTeX ($...$ for inline, $$...$$ for display)
        - Maintain a clean, organized structure
        """
        
        let customInstructions = userInstructions.isEmpty 
            ? "- Simply integrate the assistant's response with the existing card content in a natural way"
            : "- User's specific instructions: \(userInstructions)"
        
        let outputFormat = """
        
        # OUTPUT FORMAT
        Return the refined card in this exact format:
        <CARD>
        <FRONT>
        (Front side content)
        </FRONT>
        <BACK>
        (Back side content)
        </BACK>
        </CARD>
        """
        
        return basePrompt + "\n" + customInstructions + outputFormat
    }
    
    /// Call GPT API to integrate information
    private func callGPTForIntegration(
        prompt: String,
        retryCount: Int = 0,
        completion: @escaping (Result<(front: String, back: String), Error>) -> Void
    ) {
        guard let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            completion(.failure(NSError(domain: "GPTView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API key"])))
            return
        }
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are an expert flashcard creator, specializing in precise, effective learning materials."],
            ["role": "user", "content": prompt]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.2  // Lower temperature for more deterministic output
        ]
        
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60 // Longer timeout (60 seconds instead of default 30)
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Configure URLSession with longer timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        let session = URLSession(configuration: config)
        
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                // For network errors, attempt to retry up to 2 times
                if retryCount < 2 {
                    // Wait a moment before retrying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("Retrying integration call (attempt \(retryCount + 1))...")
                        self.callGPTForIntegration(
                            prompt: prompt,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    // Display error to user
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    self.showErrorToast = true
                    
                    // Automatically hide after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showErrorToast = false
                    }
                    
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received from server"
                    self.showErrorToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showErrorToast = false
                    }
                    
                    completion(.failure(NSError(domain: "GPTView", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    
                    // Try to get error message from the API response
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        
                        DispatchQueue.main.async {
                            self.errorMessage = "API Error: \(message)"
                            self.showErrorToast = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self.showErrorToast = false
                            }
                        }
                    }
                    
                    throw NSError(domain: "GPTView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
                
                // Parse the content for front and back
                let (front, back) = self.parseCardContent(content)
                
                DispatchQueue.main.async {
                    completion(.success((front: front, back: back)))
                    self.showSuccessToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showSuccessToast = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing response: \(error.localizedDescription)"
                    self.showErrorToast = true
                    
                    // Automatically hide after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showErrorToast = false
                    }
                    
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Parse the card content from GPT response
    private func parseCardContent(_ content: String) -> (front: String, back: String) {
        var front = card.front // Default to original card.front
        var back = card.back   // Default to original card.back

        let nsContent = content as NSString

        func extract(pattern: String) -> String? {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
                let range = NSRange(location: 0, length: nsContent.length)
                if let match = regex.firstMatch(in: content, options: [], range: range) {
                    if match.numberOfRanges > 1 {
                        let captureGroupRange = match.range(at: 1)
                        return nsContent.substring(with: captureGroupRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                print("Regex error for pattern \"\(pattern)\": \(error.localizedDescription)")
            }
            return nil
        }

        if let extractedFront = extract(pattern: "<FRONT>(.*?)</FRONT>"), !extractedFront.isEmpty {
            front = extractedFront
        }

        if let extractedBack = extract(pattern: "<BACK>(.*?)</BACK>"), !extractedBack.isEmpty {
            back = extractedBack
        }
        
        return (front, back)
    }

    /// Find deck containing current card (linear search)
    private func findDeck(for card: Card) -> Deck {
        return deckManager.decks.first(where: { deck in
            deck.cards.contains(where: { $0.id == card.id })
        }) ?? Deck(name: "")
    }
}

/// Chat bubble styling with math rendering support
private struct ChatBubble: View {
    let message: Message
    let onIntegrate: (Message) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var contentHeight: CGFloat = 0
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
                messageContent
                    .padding(12)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(16)
            } else if message.role == "assistant" {
                ZStack(alignment: .bottomTrailing) {
                    messageContent
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)

                    Button(action: { onIntegrate(message) }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(6)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(6)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
        .padding(.vertical, 8) // Increased vertical padding
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if shouldUseMathRendering(message.content) {
            // Use MathTextContainer for proper dynamic sizing and scrolling
            MathTextContainer(content: message.content)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.8) // Increased width
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                })
                .onPreferenceChange(ViewHeightKey.self) { height in
                    contentHeight = height
                }
        } else {
            Text(message.content)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.8) // Increased width
        }
    }
    
    /// Determines if we should use math rendering for this content
    private func shouldUseMathRendering(_ content: String) -> Bool {
        // Check for $ or $$ delimiters that indicate math content
        return content.contains("$") || 
               content.contains("\\[") || 
               content.contains("\\(") ||
               content.contains("\\begin{")
    }
}

// Height key for preference reading
private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
