import Foundation

/// A protocol that represents any Markdown content.
public protocol MarkdownContentProtocol {
  var _markdownContent: MarkdownContent { get }
}

/// A Markdown content value.
///
/// A Markdown content value consists of a sequence of blocks – structural elements like paragraphs, blockquotes, lists,
/// headings, thematic breaks, and code blocks. Some blocks, like blockquotes and list items, contain other blocks; others,
/// like headings and paragraphs, have inline text, links, emphasized text, etc.
///
/// You can create a Markdown content value by passing a Markdown-formatted string to ``init(_:)``.
///
/// ```swift
/// let content = MarkdownContent("You can try **CommonMark** [here](https://spec.commonmark.org/dingus/).")
/// ```
///
/// Alternatively, you can build a Markdown content value using a domain-specific language for blocks and inline text.
///
/// ```swift
/// let content = MarkdownContent {
///   Paragraph {
///     "You can try "
///     Strong("CommonMark")
///     SoftBreak()
///     InlineLink("here", destination: URL(string: "https://spec.commonmark.org/dingus/")!)
///     "."
///   }
/// }
/// ```
///
/// Once you have created a Markdown content value, you can display it using a ``Markdown`` view.
///
/// ```swift
/// var body: some View {
///   Markdown(self.content)
/// }
/// ```
///
/// A Markdown view also offers initializers that take a Markdown-formatted string ``Markdown/init(_:baseURL:imageBaseURL:)-63py1``,
/// or a Markdown content builder ``Markdown/init(baseURL:imageBaseURL:content:)``, so you don't need to create a
/// Markdown content value before displaying it.
///
/// ```swift
/// var body: some View {
///   VStack {
///     Markdown("You can try **CommonMark** [here](https://spec.commonmark.org/dingus/).")
///     Markdown {
///       Paragraph {
///         "You can try "
///         Strong("CommonMark")
///         SoftBreak()
///         InlineLink("here", destination: URL(string: "https://spec.commonmark.org/dingus/")!)
///         "."
///       }
///     }
///   }
/// }
/// ```
public struct MarkdownContent: Equatable, MarkdownContentProtocol {
  /// Returns a Markdown content value with the sum of the contents of all the container blocks
  /// present in this content.
  ///
  /// You can use this property to access the contents of a blockquote or a list. Returns `nil` if
  /// there are no container blocks.
  public var childContent: MarkdownContent? {
    let children = self.blocks.map(\.children).flatMap { $0 }
    return children.isEmpty ? nil : .init(blocks: children)
  }

  public var _markdownContent: MarkdownContent { self }
  let blocks: [BlockNode]

  init(blocks: [BlockNode] = []) {
    self.blocks = blocks
  }

  init(block: BlockNode) {
    self.init(blocks: [block])
  }

  init(_ components: [MarkdownContentProtocol]) {
    self.init(blocks: components.map(\._markdownContent).flatMap(\.blocks))
  }

  /// Creates a Markdown content value from a Markdown-formatted string.
  /// - Parameter markdown: A Markdown-formatted string.
  public init(_ markdown: String) {
    self.init(blocks: .init(markdown: markdown))
  }

  /// Creates a Markdown content value composed of any number of blocks.
  /// - Parameter content: A Markdown content builder that returns the blocks that form the Markdown content.
  public init(@MarkdownContentBuilder content: () -> MarkdownContent) {
    self.init(blocks: content().blocks)
  }

  /// Renders this Markdown content value as a Markdown-formatted text.
  public func renderMarkdown() -> String {
    let result = self.blocks.renderMarkdown()
    return result.hasSuffix("\n") ? String(result.dropLast()) : result
  }

  /// Renders this Markdown content value as plain text.
  public func renderPlainText() -> String {
    let result = self.blocks.renderPlainText()
    return result.hasSuffix("\n") ? String(result.dropLast()) : result
  }

  /// Renders this Markdown content value as HTML code.
  public func renderHTML() -> String {
    self.blocks.renderHTML()
  }

  /// Finds all the occurrences of the provided text within this Markdown content value.
  ///
  /// Each result references the block that contains the match. You can use the ``MarkdownSearchResult/scrollID``
  /// property of the result to scroll the corresponding `Markdown` view with `ScrollViewReader`.
  /// - Parameters:
  ///   - text: The text to look for. Empty or whitespace-only queries return an empty result set.
  ///   - options: String comparison options. The default is `caseInsensitive`.
  ///   - locale: The locale to use when performing the comparison. The default is `nil`.
  /// - Returns: All the search results found in the content ordered from top to bottom.
  public func search(
    _ text: String,
    options: String.CompareOptions = [.caseInsensitive],
    locale: Locale? = nil
  ) -> [MarkdownSearchResult] {
    let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return []
    }

    return self.blocks.enumerated().flatMap { index, block in
      self.search(query, in: block, index: index, options: options, locale: locale)
    }
  }

  private func search(
    _ text: String,
    in block: BlockNode,
    index: Int,
    options: String.CompareOptions,
    locale: Locale?
  ) -> [MarkdownSearchResult] {
    let blockText = block.renderPlainText()
    guard !blockText.isEmpty else {
      return []
    }

    var matches: [MarkdownSearchResult] = []
    var searchRange = blockText.startIndex..<blockText.endIndex

    while let range = blockText.range(of: text, options: options, range: searchRange, locale: locale) {
      let lowerBound = blockText.distance(from: blockText.startIndex, to: range.lowerBound)
      let upperBound = blockText.distance(from: blockText.startIndex, to: range.upperBound)

      matches.append(
        MarkdownSearchResult(
          blockIndex: index,
          blockText: blockText,
          matchRange: lowerBound..<upperBound,
          snippet: blockText.snippet(
            around: range,
            contextLength: MarkdownSearchResult.snippetContextLength
          )
        )
      )

      searchRange = range.upperBound..<blockText.endIndex
    }

    return matches
  }
}

/// Represents a single search result within a ``MarkdownContent`` value.
public struct MarkdownSearchResult: Identifiable, Hashable, Sendable {
  static let snippetContextLength = 32

  /// A stable identifier you can use with SwiftUI collections.
  public let id: UUID

  /// The index of the block that contains the match.
  public let blockIndex: Int

  /// The plain text of the block that contains the match.
  public let blockText: String

  /// The range of the match within ``blockText`` expressed as character offsets.
  public let matchRange: Range<Int>

  /// A human-friendly snippet centered around the match.
  public let snippet: String

  /// Creates a new search result.
  /// - Parameters:
  ///   - id: A stable identifier for the result. Defaults to a random value.
  ///   - blockIndex: The index of the block that contains the match.
  ///   - blockText: The plain text of the block that contains the match.
  ///   - matchRange: The range of the match within `blockText` expressed as character offsets.
  ///   - snippet: A human-friendly snippet centered around the match.
  public init(
    id: UUID = UUID(),
    blockIndex: Int,
    blockText: String,
    matchRange: Range<Int>,
    snippet: String
  ) {
    self.id = id
    self.blockIndex = blockIndex
    self.blockText = blockText
    self.matchRange = matchRange
    self.snippet = snippet
  }

  /// The identifier that you can pass to `ScrollViewProxy.scrollTo(_:)`.
  public var scrollID: Int { self.blockIndex }

  /// The exact text that matched the query.
  public var matchedText: String {
    guard let range = self.rangeInBlockText else {
      return ""
    }
    return String(self.blockText[range])
  }

  /// The range of the match within ``blockText``.
  public var rangeInBlockText: Range<String.Index>? {
    guard
      self.matchRange.lowerBound >= 0,
      self.matchRange.upperBound <= self.blockText.count
    else {
      return nil
    }

    let lower = self.blockText.index(self.blockText.startIndex, offsetBy: self.matchRange.lowerBound)
    let upper = self.blockText.index(self.blockText.startIndex, offsetBy: self.matchRange.upperBound)
    return lower..<upper
  }
}

private extension BlockNode {
  func renderPlainText() -> String {
    MarkdownContent(block: self).renderPlainText()
  }
}
