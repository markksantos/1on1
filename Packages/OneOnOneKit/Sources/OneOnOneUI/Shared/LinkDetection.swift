import Foundation
import SwiftUI

/// Detects URLs in text and returns an AttributedString with clickable links.
func linkAttributedString(from text: String, isFromMe: Bool = false) -> AttributedString {
    var result = AttributedString(text)

    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return result
    }

    let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))

    for match in matches {
        guard let range = Range(match.range, in: text),
              let url = match.url,
              let attrRange = Range(range, in: result) else { continue }

        result[attrRange].link = url
        result[attrRange].underlineStyle = .single
    }

    return result
}
