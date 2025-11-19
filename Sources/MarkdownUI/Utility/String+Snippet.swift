import Foundation

extension String {
  func snippet(around range: Range<String.Index>, contextLength: Int) -> String {
    guard !self.isEmpty else {
      return ""
    }

    let adjustedContext = max(0, contextLength)
    let lowerBound = self.index(range.lowerBound, offsetBy: -adjustedContext, limitedBy: self.startIndex)
      ?? self.startIndex
    let upperBound = self.index(range.upperBound, offsetBy: adjustedContext, limitedBy: self.endIndex)
      ?? self.endIndex

    var snippet = String(self[lowerBound..<upperBound])

    if lowerBound > self.startIndex {
      snippet = "\u{2026}" + snippet
    }

    if upperBound < self.endIndex {
      snippet += "\u{2026}"
    }

    return snippet
  }
}
