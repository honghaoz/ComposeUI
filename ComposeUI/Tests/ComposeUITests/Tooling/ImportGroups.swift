//
//  ImportGroups.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/26.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Groups the imports at the top of a Swift file, for `scripts/imports/group-imports.sh`.
///
/// The imports go in the groups of a configuration, in its order, with a blank line between groups. In a group, the
/// `#if` blocks of imports come first, and the order of the other imports is left to SwiftFormat's `sortImports`, so the
/// two tools can't disagree.
///
/// The test target compiles this file to test it, and the script compiles it with its entry point,
/// `scripts/imports/group-imports.swift`, so it uses Foundation only.
enum ImportGroups {

  /// The groups of the imports, and the files they apply to.
  struct Config: Equatable {

    /// The groups, in order, each with the modules it takes.
    let groups: [Set<String>]

    /// The index of the group that takes the modules that no group lists.
    let otherModulesGroup: Int

    /// The directories and files whose Swift files the groups apply to, relative to the repository.
    let paths: [String]

    /// The directories and files in the paths that the groups don't apply to, relative to the repository.
    let excludedPaths: [String]

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - groups: The groups, in order, each with the modules it takes.
    ///   - otherModulesGroup: The index of the group that takes the modules that no group lists.
    ///   - paths: The directories and files whose Swift files the groups apply to, relative to the repository.
    ///   - excludedPaths: The directories and files in the paths that the groups don't apply to.
    init(groups: [Set<String>], otherModulesGroup: Int, paths: [String], excludedPaths: [String]) {
      self.groups = groups
      self.otherModulesGroup = otherModulesGroup
      self.paths = paths
      self.excludedPaths = excludedPaths
    }

    /// Creates a configuration from its text.
    ///
    /// Each line is a key and its values, separated by spaces, and a `#` starts a comment:
    /// - `paths: <path>...`: The directories and files whose Swift files the groups apply to.
    /// - `exclude: <path>...`: The directories and files in the paths that the groups don't apply to.
    /// - `group: <module>...`: A group's modules, in the order of the groups, with `*` for the modules that no group
    ///   lists.
    ///
    /// - Parameter text: The configuration's text.
    init(parsing text: String) throws {
      var groups: [Set<String>] = []
      var otherModulesGroup: Int?
      var paths: [String] = []
      var excludedPaths: [String] = []
      for (offset, rawLine) in text.components(separatedBy: "\n").enumerated() {
        let line = rawLine.prefix(while: { $0 != "#" }).trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else {
          continue
        }
        guard let colon = line.firstIndex(of: ":") else {
          throw ConfigError("line \(offset + 1): expected a key and its values, as `key: values`")
        }

        let key = line[..<colon].trimmingCharacters(in: .whitespaces)
        let values = line[line.index(after: colon)...].split(whereSeparator: \.isWhitespace).map { String($0) }
        switch key {
        case "paths":
          paths += values
        case "exclude":
          excludedPaths += values
        case "group":
          if values == ["*"] {
            guard otherModulesGroup == nil else {
              throw ConfigError("line \(offset + 1): a second group for the modules that no group lists")
            }
            otherModulesGroup = groups.count
            groups.append([])
          } else {
            guard !values.isEmpty, !values.contains("*") else {
              throw ConfigError("line \(offset + 1): a group lists its modules, or is `*` alone")
            }
            if let module = values.first(where: { module in groups.contains { $0.contains(module) } }) {
              throw ConfigError("line \(offset + 1): \(module) is in two groups")
            }
            groups.append(Set(values))
          }
        default:
          throw ConfigError("line \(offset + 1): unknown key `\(key)`")
        }
      }

      guard let otherModulesGroup else {
        throw ConfigError("no `group: *` for the modules that no group lists")
      }
      guard !paths.isEmpty else {
        throw ConfigError("no `paths` to apply the groups to")
      }
      self.init(groups: groups, otherModulesGroup: otherModulesGroup, paths: paths, excludedPaths: excludedPaths)
    }

    /// Returns the index of a module's group, from the module's first component, so that a submodule goes with its
    /// module.
    ///
    /// - Parameter module: The module, such as `UIKit` or `UIKit.UIGestureRecognizerSubclass`.
    /// - Returns: The index of the module's group.
    func group(of module: String) -> Int {
      let name = String(module.prefix(while: { $0 != "." }))
      return groups.firstIndex(where: { $0.contains(name) }) ?? otherModulesGroup
    }
  }

  /// An error in a configuration.
  struct ConfigError: Error, Equatable, CustomStringConvertible {

    /// What's wrong, with the line when it's about one.
    let description: String

    /// Creates an error.
    ///
    /// - Parameter description: What's wrong.
    init(_ description: String) {
      self.description = description
    }
  }

  /// The result of grouping a file's imports.
  enum Outcome: Equatable {

    /// The file's text with its imports grouped, the same text when they already are.
    case grouped(String)

    /// The imports can't be grouped, because of the line, counted from 1, for the reason.
    case unsupported(line: Int, reason: String)
  }

  /// Groups the imports at the top of a Swift file.
  ///
  /// The imports are the ones after the file's leading comments and before its first other line, with the `#if` blocks
  /// that contain only imports, and after the `#if` lines that wrap the whole file, whose `#endif` lines end it. Those
  /// stay above the imports with a blank line after them, and their `#endif` lines get a blank line before them. Another
  /// `#if` before the imports, such as one around a platform's part of the file, starts the code, which leaves the file
  /// alone. A comment in an `#if` block of imports moves with the block. A comment between imports, an `#if` block that
  /// imports modules of different groups, a line with more than an import and a comment, or an import after a block
  /// comment on its line, makes the imports unsupported, as the grouping doesn't know where it belongs.
  ///
  /// - Parameters:
  ///   - text: The file's text.
  ///   - config: The configuration.
  /// - Returns: The file's text with its imports grouped, or why they can't be.
  static func group(_ text: String, config: Config) -> Outcome {
    let lines = text.components(separatedBy: "\n")

    var index = 0
    while index < lines.count, let next = lineAfterComment(lines, at: index) {
      index = next
    }
    var headerEnd = index
    while headerEnd > 0, isBlank(lines[headerEnd - 1]) {
      headerEnd -= 1
    }

    var wrappers: [String] = []
    var wrapperEnd: Int?
    var items: [Item] = []
    var codeStart = lines.count
    scan: while index < lines.count {
      let line = lines[index]
      if isBlank(line) {
        index += 1
      } else if let module = importedModule(line) {
        items.append(Item(lines: [line], modules: [module], isBlock: false, line: index + 1))
        index += 1
      } else if isDirective(line, "#if") {
        switch importBlock(lines, from: index) {
        case .imports(let end, let modules):
          items.append(Item(lines: Array(lines[index ... end]), modules: modules, isBlock: true, line: index + 1))
          index = end + 1
        case .unsupported(let lineIndex, let reason):
          return .unsupported(line: lineIndex + 1, reason: reason)
        case .other:
          if items.isEmpty, let end = endOfBlock(lines, from: index), endsTheFile(lines, after: end) {
            wrappers.append(line)
            wrapperEnd = end
            index += 1
          } else {
            codeStart = index
            break scan
          }
        }
      } else if let next = lineAfterComment(lines, at: index) {
        if importFollows(lines, from: next) {
          return .unsupported(line: index + 1, reason: "a comment between imports")
        } else {
          codeStart = index
          break scan
        }
      } else if restAfterImportKeyword(line) != nil {
        return .unsupported(line: index + 1, reason: Constants.unreadableImportReason)
      } else if let end = importAfterBlockComment(lines, at: index) {
        return .unsupported(line: end + 1, reason: Constants.importAfterBlockCommentReason)
      } else {
        codeStart = index
        break scan
      }
    }

    guard !items.isEmpty else {
      return .grouped(text)
    }

    var groups = Array(repeating: (blocks: [Item](), imports: [Item]()), count: config.groups.count)
    for item in items {
      let indices = Set(item.modules.map(config.group(of:)))
      guard indices.count == 1, let groupIndex = indices.first else {
        return .unsupported(line: item.line, reason: "an #if block that imports modules of different groups")
      }
      if item.isBlock {
        groups[groupIndex].blocks.append(item)
      } else {
        groups[groupIndex].imports.append(item)
      }
    }

    var output = Array(lines[0 ..< headerEnd])
    if !output.isEmpty {
      output.append("")
    }
    if !wrappers.isEmpty {
      output += wrappers
      output.append("")
    }
    var isFirstGroup = true
    for group in groups where !group.blocks.isEmpty || !group.imports.isEmpty {
      if !isFirstGroup {
        output.append("")
      }
      isFirstGroup = false

      // the blocks are ordered by the first module they import, so that the order doesn't depend on where they were
      let blocks = group.blocks.enumerated().sorted { lhs, rhs in
        let lhsModule = lhs.element.modules[0].lowercased()
        let rhsModule = rhs.element.modules[0].lowercased()
        return lhsModule == rhsModule ? lhs.offset < rhs.offset : lhsModule < rhsModule
      }
      for item in blocks.map(\.element) + group.imports {
        output += item.lines
      }
    }
    output.append("")

    // a file-wide #if has a blank line after it, so the #endif lines that end the file have one before them, for the two
    // ends to look alike
    var code = Array(lines[codeStart...])
    if let wrapperEnd, wrapperEnd > codeStart {
      let end = wrapperEnd - codeStart
      var blankStart = end
      while blankStart > 0, isBlank(code[blankStart - 1]) {
        blankStart -= 1
      }
      if blankStart > 0 {
        code.replaceSubrange(blankStart ..< end, with: [""])
      }
    }
    output += code
    return .grouped(output.joined(separator: "\n"))
  }

  /// Returns whether a file's imports are in the same groups as in its grouped text, whatever their order in a group,
  /// which SwiftFormat's `sortImports` checks.
  ///
  /// - Parameters:
  ///   - text: The file's text.
  ///   - grouped: The file's text with its imports grouped.
  /// - Returns: Whether the imports are in the same groups.
  static func hasSameGroups(_ text: String, as grouped: String) -> Bool {
    sortingRunsOfImports(text) == sortingRunsOfImports(grouped)
  }

  // MARK: - Private

  /// An import, or an `#if` block of imports, at the top of a file.
  private struct Item {

    /// The lines of the import or the block.
    let lines: [String]

    /// The modules it imports.
    let modules: [String]

    /// Whether it's an `#if` block.
    let isBlock: Bool

    /// The line where it starts, counted from 1.
    let line: Int
  }

  /// Returns the module that a line imports, `nil` for a line that isn't an import.
  ///
  /// - Parameter line: The line.
  /// - Returns: The module, with its submodules, such as `UIKit.UIGestureRecognizerSubclass`.
  private static func importedModule(_ line: String) -> String? {
    guard var rest = restAfterImportKeyword(line) else {
      return nil
    }
    for kind in Constants.importKinds where rest.hasPrefix(kind) && rest.dropFirst(kind.count).first?.isWhitespace == true {
      rest = rest.dropFirst(kind.count).drop(while: \.isWhitespace)
      break
    }

    var module = rest.prefix(while: isIdentifierCharacter)
    guard let first = module.first, !first.isNumber else {
      return nil
    }
    var tail = rest.dropFirst(module.count)
    while tail.first == ".", tail.dropFirst().first.map(isIdentifierCharacter) == true {
      let component = tail.dropFirst().prefix(while: isIdentifierCharacter)
      module = rest.prefix(module.count + 1 + component.count)
      tail = tail.dropFirst(1 + component.count)
    }
    tail = tail.drop(while: \.isWhitespace)
    if tail.hasPrefix("/*"), let close = tail.range(of: "*/") {
      tail = tail[close.upperBound...].drop(while: \.isWhitespace)
    }
    guard tail.isEmpty || tail.hasPrefix("//") else {
      return nil
    }
    return String(module)
  }

  /// Returns the rest of a line after its `import` keyword, `nil` for a line that doesn't start with one after its
  /// attributes.
  ///
  /// - Parameter line: The line.
  /// - Returns: The rest of the line, without its leading whitespace.
  private static func restAfterImportKeyword(_ line: String) -> Substring? {
    var rest = line.drop(while: \.isWhitespace)
    while rest.first == "@" {
      rest = rest.dropFirst().drop(while: isIdentifierCharacter)
      if rest.first == "(" {
        guard let close = rest.firstIndex(of: ")") else {
          return nil
        }
        rest = rest[rest.index(after: close)...]
      }
      rest = rest.drop(while: \.isWhitespace)
    }

    guard rest.hasPrefix("import"), rest.dropFirst("import".count).first?.isWhitespace == true else {
      return nil
    }
    return rest.dropFirst("import".count).drop(while: \.isWhitespace)
  }

  /// What an `#if` block at the top of a file contains.
  private enum Block: Equatable {

    /// Imports and comments, with the index of the block's `#endif` and the modules it imports, without the ones in its
    /// comments.
    case imports(end: Int, modules: [String])

    /// A line that makes the imports unsupported, such as two imports on one line, with its index and why.
    case unsupported(lineIndex: Int, reason: String)

    /// Other lines, or no import.
    case other
  }

  /// Returns what the `#if` block at a line contains, which it reads to the block's `#endif` while the block has only
  /// imports and comments.
  ///
  /// The block moves whole, so a comment in it belongs to it, unlike a comment between imports.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - start: The index of the block's `#if`.
  /// - Returns: What the block contains.
  private static func importBlock(_ lines: [String], from start: Int) -> Block {
    var depth = 0
    var modules: [String] = []
    var index = start
    while index < lines.count {
      let line = lines[index]
      if isDirective(line, "#if") {
        depth += 1
      } else if isDirective(line, "#endif") {
        depth -= 1
        if depth == 0 {
          return modules.isEmpty ? .other : .imports(end: index, modules: modules)
        }
      } else if let next = lineAfterComment(lines, at: index) {
        index = next
        continue
      } else if let module = importedModule(line) {
        modules.append(module)
      } else if restAfterImportKeyword(line) != nil {
        return .unsupported(lineIndex: index, reason: Constants.unreadableImportReason)
      } else if let end = importAfterBlockComment(lines, at: index) {
        return .unsupported(lineIndex: end, reason: Constants.importAfterBlockCommentReason)
      } else if !isDirective(line, "#elseif"), !isDirective(line, "#else") {
        return .other
      }
      index += 1
    }
    return .other
  }

  /// Returns the index of the `#endif` of the `#if` block at a line, `nil` when the block doesn't end.
  ///
  /// The lines of block comments and multiline string literals are skipped, as an `#if` in them, such as in a template
  /// or a test's sample code, isn't a directive.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - start: The index of the block's `#if`.
  /// - Returns: The index of the block's `#endif`.
  private static func endOfBlock(_ lines: [String], from start: Int) -> Int? {
    var depth = 0
    var isInString = false
    var index = start
    while index < lines.count {
      let line = lines[index]
      // a line with an odd number of `"""` opens or closes a multiline string literal
      let togglesString = line.components(separatedBy: "\"\"\"").count.isMultiple(of: 2)
      if isInString {
        isInString = !togglesString
        index += 1
      } else if let next = lineAfterComment(lines, at: index) {
        // comments are skipped before the quotes are counted, as the quotes in a comment don't open a string
        index = next
      } else {
        if togglesString {
          isInString = true
        } else if isDirective(line, "#if") {
          depth += 1
        } else if isDirective(line, "#endif") {
          depth -= 1
          if depth == 0 {
            return index
          }
        }
        index += 1
      }
    }
    return nil
  }

  /// Returns whether only blank lines, and the `#endif` lines of the blocks around a block, follow its `#endif` to the
  /// end of a file.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the block's `#endif`.
  /// - Returns: Whether the block's `#endif` ends the file.
  private static func endsTheFile(_ lines: [String], after index: Int) -> Bool {
    lines[(index + 1)...].allSatisfy { isBlank($0) || isDirective($0, "#endif") }
  }

  /// Returns whether an import, read or not, or an `#if` block with one, comes first from a line on, after comments and
  /// blank lines.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: Whether an import follows.
  private static func importFollows(_ lines: [String], from index: Int) -> Bool {
    var next = index
    while next < lines.count, let after = lineAfterComment(lines, at: next) {
      next = after
    }
    guard next < lines.count else {
      return false
    }
    return restAfterImportKeyword(lines[next]) != nil
      || importAfterBlockComment(lines, at: next) != nil
      || (isDirective(lines[next], "#if") && importBlock(lines, from: next) != .other)
  }

  /// Returns the lines of a text with each run of imports sorted.
  ///
  /// - Parameter text: The text.
  /// - Returns: The lines, with each run of consecutive import lines sorted.
  private static func sortingRunsOfImports(_ text: String) -> [String] {
    var lines = text.components(separatedBy: "\n")
    var start = 0
    while start < lines.count {
      guard importedModule(lines[start]) != nil else {
        start += 1
        continue
      }
      var end = start
      while end < lines.count, importedModule(lines[end]) != nil {
        end += 1
      }
      lines[start ..< end].sort()
      start = end
    }
    return lines
  }

  /// Returns whether a line is a compiler directive, such as `#if` or `#endif`, with or without a condition.
  ///
  /// - Parameters:
  ///   - line: The line.
  ///   - directive: The directive, such as `#if`.
  /// - Returns: Whether the line is the directive.
  private static func isDirective(_ line: String, _ directive: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix(directive) else {
      return false
    }
    let next = trimmed.dropFirst(directive.count).first
    return next == nil || next == "(" || next?.isWhitespace == true
  }

  /// Returns the index of the line after the blank line, the line comment or the block comment at a line, `nil` for a
  /// line of code, or for a block comment with an import after it on its last line, which isn't only a comment.
  ///
  /// A block comment is skipped whole, as the lines in it, such as the code of a template, aren't the file's.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: The index of the line after the comment.
  private static func lineAfterComment(_ lines: [String], at index: Int) -> Int? {
    let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty || trimmed.hasPrefix("//") {
      return index + 1
    } else if let end = blockCommentEnd(lines, at: index), restAfterImportKeyword(String(end.rest)) == nil {
      return end.line + 1
    } else {
      return nil
    }
  }

  /// Returns the index of the line where the block comment at a line ends, when an import follows the comment on that
  /// line, as in `/* views */ import UIKit`.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: The index of the line where the comment ends, `nil` when the line doesn't start a block comment or no
  ///   import follows it.
  private static func importAfterBlockComment(_ lines: [String], at index: Int) -> Int? {
    guard let end = blockCommentEnd(lines, at: index), restAfterImportKeyword(String(end.rest)) != nil else {
      return nil
    }
    return end.line
  }

  /// Returns where the block comment at a line ends.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: The index of the line where the comment ends, the last line when it doesn't end, with the rest of that
  ///   line after the comment, `nil` for a line that doesn't start a block comment.
  private static func blockCommentEnd(_ lines: [String], at index: Int) -> (line: Int, rest: Substring)? {
    let trimmed = lines[index].drop(while: \.isWhitespace)
    guard trimmed.hasPrefix("/*") else {
      return nil
    }
    var end = index
    var text = trimmed.dropFirst(2)
    var close = text.range(of: "*/")
    while close == nil, end + 1 < lines.count {
      end += 1
      text = Substring(lines[end])
      close = text.range(of: "*/")
    }
    guard let close else {
      return (end, "")
    }
    return (end, text[close.upperBound...])
  }

  /// Returns whether a line is blank.
  ///
  /// - Parameter line: The line.
  /// - Returns: Whether the line is blank.
  private static func isBlank(_ line: String) -> Bool {
    line.allSatisfy(\.isWhitespace)
  }

  /// Returns whether a character can be part of an identifier.
  ///
  /// - Parameter character: The character.
  /// - Returns: Whether the character can be part of an identifier.
  private static func isIdentifierCharacter(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "_"
  }

  // MARK: - Constants

  private enum Constants {

    /// The kinds of declaration that an import can import alone, as in `import struct Foundation.Date`.
    static let importKinds = ["typealias", "struct", "class", "enum", "protocol", "let", "var", "func"]

    /// Why an import that can't be read makes the imports unsupported.
    static let unreadableImportReason = "a line with more than an import and a comment"

    /// Why an import after a block comment on its line makes the imports unsupported.
    static let importAfterBlockCommentReason = "an import after a block comment on its line"
  }
}
