import SwiftUI

/// Container for MathTextView that handles scrolling and dynamic height
struct MathTextContainer: View {
    let content: String
    @State private var height: CGFloat = 150
    let maxHeight: CGFloat = 1800 // allow scrolling for very long messages
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            MathTextView(content: content, onHeightChange: { newHeight in
                // Add a generous buffer to the height to prevent cutting off content
                let adjustedHeight = newHeight + 24 // buffer for padding
                DispatchQueue.main.async {
                    self.height = min(adjustedHeight, maxHeight)
                }
            })
            .frame(height: height)
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.2), value: height)
        .onAppear {
            self.height = min(estimateInitialHeight(for: content), maxHeight)
        }
    }
    
    /// Estimate an initial height based on content length to reduce layout jumps
    private func estimateInitialHeight(for text: String) -> CGFloat {
        let lines = max(1, text.split(separator: "\n").count)
        let estimated = CGFloat(lines) * 22.0 + 32 // rough per-line height + padding
        return max(estimated, 100)
    }
} 