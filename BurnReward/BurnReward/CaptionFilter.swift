import Foundation

/// Caption hygiene before a line leaves the device.
///
/// Honest about what this is: a **wordlist plus a URL stripper**, not a
/// moderation system. It stops casual slurs and turns captions into a useless
/// spam vector; it cannot judge context, and a determined person routes around
/// any list. The actual answer to abusive content is the report/block flow and
/// the `hidden` kill switch (P4) — this filter just keeps the obvious cases
/// from ever being posted, so those tools handle the hard cases instead of the
/// easy ones.
enum CaptionFilter {
    static let maxLength = 100

    /// Cleans a caption for posting. Returns nil when nothing usable is left,
    /// so an empty result posts as "no caption" rather than an empty string.
    static func clean(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        text = strippingLinks(text)
        // Collapse runs of whitespace/newlines — a caption is one line, and
        // this also defeats the "vertical ASCII wall" layout trick.
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        text = String(text.prefix(maxLength))

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Rejects a caption outright (shown to the writer, nothing posted).
    static func rejection(_ raw: String) -> String? {
        guard let cleaned = clean(raw) else { return nil }
        if containsBlockedWord(cleaned) {
            return "That caption contains language that can't be posted."
        }
        return nil
    }

    // MARK: - Internals

    private static func strippingLinks(_ text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var result = text
        // Replace back to front so earlier ranges stay valid.
        for match in detector.matches(in: text, range: range).reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(matchRange, with: "")
        }
        return result
    }

    /// Whole-word match against a deliberately small list of unambiguous slurs
    /// and harassment terms. Substring matching is avoided on purpose — it
    /// produces the classic false positives that punish innocent words.
    private static func containsBlockedWord(_ text: String) -> Bool {
        let words = text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        return words.contains { blocked.contains($0) }
    }

    /// Kept short and unambiguous. Extend from real reports rather than
    /// guesswork — an overlong list mostly generates false positives.
    private static let blocked: Set<String> = [
        "fag", "faggot", "kike", "nigger", "nigga", "retard", "retarded",
        "tranny", "spic", "chink", "wetback", "whore", "slut", "cunt",
        "rape", "rapist", "kys",
    ]
}
