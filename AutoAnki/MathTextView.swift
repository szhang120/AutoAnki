import SwiftUI
import WebKit

/// A view that renders text with LaTeX math expressions using MathJax
struct MathTextView: UIViewRepresentable {
    let content: String
    var onHeightChange: ((CGFloat) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure the web view
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Add message handler for height changes
        contentController.add(context.coordinator, name: "heightChange")
        contentController.add(context.coordinator, name: "log")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create HTML with MathJax
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                    color: black;
                    line-height: 1.5;
                    overflow-wrap: break-word;
                    word-wrap: break-word;
                    hyphens: auto;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: white;
                    }
                    .mjx-math {
                        color: white !important;
                    }
                }
                .content {
                    padding: 8px;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    width: 100%;
                    box-sizing: border-box;
                }
                .mjx-chtml {
                    display: inline-block;
                    line-height: 0;
                    text-indent: 0;
                    text-align: left;
                    text-transform: none;
                    font-style: normal;
                    font-weight: normal;
                    font-size: 100%;
                    font-size-adjust: none;
                    letter-spacing: normal;
                    word-wrap: normal;
                    word-spacing: normal;
                    white-space: nowrap;
                    direction: ltr;
                    padding: 1px 0;
                    margin-bottom: 5px; /* Add space after math */
                }
                /* For display math ($$...$$) */
                .MJXc-display {
                    overflow-x: auto;
                    overflow-y: hidden;
                    margin: 10px 0;
                    padding: 5px 0;
                    width: 100%;
                }
                .mjx-math {
                    color: inherit;
                    max-width: 100%;
                    overflow-x: auto;
                }
                /* Make sure all math is fully visible */
                .mjx-chtml {
                    max-width: 100%;
                    overflow-x: auto;
                    overflow-y: hidden;
                }
                code {
                    font-family: SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                    padding: 0.2em 0.4em;
                    margin: 0;
                    font-size: 85%;
                    background-color: rgba(175, 184, 193, 0.2);
                    border-radius: 6px;
                }
                /* Handle math overflow */
                mjx-container {
                    max-width: 100%;
                    overflow-x: auto;
                    overflow-y: hidden;
                    padding-bottom: 5px;
                }
            </style>
        </head>
        <body>
            <div class="content">
                \(formatContentForMathJax(content))
            </div>
            <script>
                // Logging helper
                function log(msg) {
                    window.webkit.messageHandlers.log.postMessage(msg);
                }
                
                // Auto-resize based on content
                function updateHeight() {
                    // Calculate the document height with a generous margin to prevent cut-off
                    // Get the full document scrollHeight plus extra padding
                    const calculatedHeight = document.body.scrollHeight + 40;
                    window.webkit.messageHandlers.heightChange.postMessage(calculatedHeight);
                }
                
                window.addEventListener('load', function() {
                    setTimeout(updateHeight, 200);
                });
                
                // Additional safeguard to ensure height is updated after DOM changes
                const observer = new MutationObserver(function(mutations) {
                    setTimeout(updateHeight, 100);
                });
                
                observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true
                });
                
                // Configure MathJax
                window.MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\(', '\\)']],
                        displayMath: [['$$', '$$'], ['\\[', '\\]']],
                        processEscapes: true,
                        processEnvironments: true,
                        packages: ['base', 'ams', 'noerrors', 'noundefined']
                    },
                    svg: {
                        fontCache: 'global'
                    },
                    options: {
                        skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
                        ignoreHtmlClass: 'tex2jax_ignore',
                        processHtmlClass: 'tex2jax_process'
                    },
                    startup: {
                        pageReady: function() {
                            return MathJax.startup.defaultPageReady().then(function() {
                                try {
                                    // Force a reflow to ensure proper layout
                                    document.body.style.display = 'none';
                                    document.body.offsetHeight;
                                    document.body.style.display = '';
                                    
                                    // Make all math content horizontally scrollable if needed
                                    document.querySelectorAll('.mjx-chtml').forEach(function(el) {
                                        if (el.scrollWidth > el.clientWidth) {
                                            el.style.overflowX = 'auto';
                                            el.style.maxWidth = '100%';
                                            el.style.display = 'block';
                                            el.style.padding = '5px 0';
                                        }
                                    });
                                    
                                    // Ensure updateHeight is called after MathJax processing
                                    setTimeout(updateHeight, 200);
                                    
                                    // Add a second call with longer delay to ensure all math is rendered
                                    setTimeout(updateHeight, 500);
                                    
                                    // Add a third call for complex math expressions
                                    setTimeout(updateHeight, 1000);
                                } catch (error) {
                                    log('Error in MathJax processing: ' + error.message);
                                }
                            });
                        }
                    }
                };
                
                // Handle MathJax errors
                window.addEventListener('error', function(event) {
                    log('JavaScript error: ' + event.message);
                });
                
                // Resize observer for dynamic content changes
                if (window.ResizeObserver) {
                    const observer = new ResizeObserver(() => {
                        updateHeight();
                    });
                    observer.observe(document.body);
                }
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    /// Format content to handle LaTeX and HTML formatting
    private func formatContentForMathJax(_ text: String) -> String {
        // Step 0: Basic Markdown to HTML for bold (**text**) and italics (*text*)
        let markdownConverted = applyBasicMarkdownFormatting(text)

        // Step 1: Convert line breaks to <br> tags (preserve any existing <br> tags)
        let withLineBreaks = markdownConverted.replacingOccurrences(of: "\n", with: "<br>")

        // Step 2: Format inline code with <code> tags
        let codePattern = try? NSRegularExpression(pattern: "`([^`]+)`")
        let codeFormatted: String

        if let codePattern = codePattern {
            let range = NSRange(withLineBreaks.startIndex..<withLineBreaks.endIndex, in: withLineBreaks)
            codeFormatted = codePattern.stringByReplacingMatches(
                in: withLineBreaks,
                options: [],
                range: range,
                withTemplate: "<code>$1</code>"
            )
        } else {
            codeFormatted = withLineBreaks
        }

        // Step 3: Protect math delimiters and escape HTML but allow certain tags
        return processMathContent(codeFormatted)
    }
    
    /// Convert simple markdown bold/italic to HTML equivalents
    private func applyBasicMarkdownFormatting(_ input: String) -> String {
        var output = input
        // Bold **text**
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*") {
            let range = NSRange(location: 0, length: output.utf16.count)
            output = boldRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "<strong>$1</strong>")
        }

        // Italic *text* (single asterisks) - make sure not to replace bold markers already handled
        if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)") {
            let range = NSRange(location: 0, length: output.utf16.count)
            output = italicRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "<em>$1</em>")
        }

        return output
    }
    
    /// Process content to preserve math delimiters while escaping HTML elsewhere
    private func processMathContent(_ text: String) -> String {
        var result = ""
        var remaining = text
        
        // Single $ for inline math
        while let dollarRange = remaining.range(of: "$") {
            // Add escaped HTML for content before the math
            let beforeMath = String(remaining[..<dollarRange.lowerBound])
            result += escapeHTML(beforeMath)
            
            // Remove processed part
            remaining = String(remaining[dollarRange.lowerBound...])
            
            // Find closing dollar
            if let closingRange = remaining.range(of: "$", range: remaining.index(after: remaining.startIndex)..<remaining.endIndex) {
                // Add the entire math expression (including $ signs)
                let mathExpression = String(remaining[..<closingRange.upperBound])
                result += mathExpression
                
                // Remove processed math part
                if closingRange.upperBound < remaining.endIndex {
                    remaining = String(remaining[closingRange.upperBound...])
                } else {
                    remaining = ""
                    break
                }
            } else {
                // No closing $ found - treat as regular text
                result += "$"
                if remaining.count > 1 {
                    remaining = String(remaining[remaining.index(after: remaining.startIndex)...])
                } else {
                    break
                }
            }
        }
        
        // Add any remaining content with HTML escaped
        if !remaining.isEmpty {
            result += escapeHTML(remaining)
        }
        
        return result
    }
    
    /// Escape HTML special characters but allow basic formatting tags
    private func escapeHTML(_ text: String) -> String {
        // Allowed tags we want to keep unescaped (lowercase)
        let allowed = ["br", "strong", "b", "em", "i", "ul", "ol", "li", "p"]

        var output = text

        // Temporary placeholders for allowed tags
        for tag in allowed {
            output = output.replacingOccurrences(of: "<\(tag)>", with: "%%ALLOWED_OPEN_\(tag.uppercased())%%")
            output = output.replacingOccurrences(of: "</\(tag)>", with: "%%ALLOWED_CLOSE_\(tag.uppercased())%%")
            // Self-closing variants for br
            output = output.replacingOccurrences(of: "<\(tag)/>", with: "%%ALLOWED_SELFCLOSE_\(tag.uppercased())%%")
        }

        // Now escape the rest
        output = output
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Restore placeholders
        for tag in allowed {
            output = output.replacingOccurrences(of: "%%ALLOWED_OPEN_\(tag.uppercased())%%", with: "<\(tag)>")
            output = output.replacingOccurrences(of: "%%ALLOWED_CLOSE_\(tag.uppercased())%%", with: "</\(tag)>")
            output = output.replacingOccurrences(of: "%%ALLOWED_SELFCLOSE_\(tag.uppercased())%%", with: "<\(tag)/>")
        }

        return output
    }
    
    // Coordinator to handle WKWebView message events
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MathTextView
        
        init(_ parent: MathTextView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "heightChange":
                if let height = message.body as? CGFloat {
                    parent.onHeightChange?(height)
                }
            case "log":
                if let log = message.body as? String {
                    print("MathJax Log:", log)
                }
            default:
                break
            }
        }
    }
}

// No additional structs or classes here 