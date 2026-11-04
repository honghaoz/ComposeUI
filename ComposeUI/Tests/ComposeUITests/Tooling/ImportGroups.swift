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
  /// alone. A comment in an `#if` block of imports moves with the block, and a comment on an import's line moves with the
  /// import. A comment between imports, an `#if` block that imports modules of different groups, a line with more than
  /// an import and a comment, or an import with a block comment that spans lines, makes the imports unsupported, as the
  /// grouping doesn't know where it belongs.
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
      } else {
        switch lineKind(lines, at: index) {
        case .comment(let next):
          if importFollows(lines, from: next) {
            return .unsupported(line: index + 1, reason: "a comment between imports")
          } else {
            codeStart = index
            break scan
          }
        case .import(let module):
          items.append(Item(lines: [line], modules: [module], isBlock: false, line: index + 1))
          index += 1
        case .unsupportedImport(let reason):
          return .unsupported(line: index + 1, reason: reason)
        case .code:
          codeStart = index
          break scan
        }
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

  /// What a line is, from its code without its comments.
  private enum LineKind {

    /// A blank line or comments, with the index of the line after them.
    case comment(next: Int)

    /// An import of a module, with its submodules, such as `UIKit.UIGestureRecognizerSubclass`.
    case `import`(String)

    /// An import that can't be grouped, with why.
    case unsupportedImport(String)

    /// Code that isn't an import.
    case code
  }

  /// Returns what a line is, from its code without its comments.
  ///
  /// A block comment that goes on past the line makes the lines it spans part of the line: they're comments when the
  /// line has no code, and an import on the line can't be grouped, as it can't move without them.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: What the line is.
  private static func lineKind(_ lines: [String], at index: Int) -> LineKind {
    let span = codeSpan(lines, at: index)
    if isBlank(span.text) {
      return .comment(next: span.end + 1)
    } else if let rest = restAfterImportKeyword(span.text) {
      if span.end > index || span.depth > 0 {
        return .unsupportedImport(Constants.importWithAMultilineCommentReason)
      } else if let module = importedModule(after: rest) {
        return .import(module)
      } else {
        return .unsupportedImport(Constants.unreadableImportReason)
      }
    } else {
      return .code
    }
  }

  /// Returns the code of a line, read on through the lines that a block comment on it spans while there's no code.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: The code, the index of the last line read, and the depth of the block comments open at its end.
  private static func codeSpan(_ lines: [String], at index: Int) -> (text: String, end: Int, depth: Int) {
    var depth = 0
    var end = index
    var text = code(of: lines[index], depth: &depth)
    while isBlank(text), depth > 0, end + 1 < lines.count {
      end += 1
      text += code(of: lines[end], depth: &depth)
    }
    return (text, end, depth)
  }

  /// Returns the code of a line, with each of its comments replaced by a space.
  ///
  /// String literals aren't recognized: a `//` or a `/*` in one ends the code early, which leaves a line of code a line
  /// of code, as the code before it isn't blank.
  ///
  /// - Parameters:
  ///   - line: The line.
  ///   - depth: The depth of the block comments, which nest in Swift, that are open at the start of the line, set to
  ///     the depth at its end.
  /// - Returns: The line's code.
  private static func code(of line: String, depth: inout Int) -> String {
    var code = ""
    var rest = Substring(line)
    while let character = rest.first {
      if rest.hasPrefix("/*") {
        if depth == 0 {
          code.append(" ")
        }
        depth += 1
        rest = rest.dropFirst(2)
      } else if depth > 0 {
        if rest.hasPrefix("*/") {
          depth -= 1
          rest = rest.dropFirst(2)
        } else {
          rest = rest.dropFirst()
        }
      } else if rest.hasPrefix("//") {
        break
      } else {
        code.append(character)
        rest = rest.dropFirst()
      }
    }
    return code
  }

  /// Returns the module that an import imports, `nil` when more code follows the module, such as a second import.
  ///
  /// - Parameter rest: The import's code after its `import` keyword, without its comments.
  /// - Returns: The module, with its submodules, such as `UIKit.UIGestureRecognizerSubclass`.
  private static func importedModule(after rest: Substring) -> String? {
    var rest = rest
    for kind in Constants.importKinds where rest.hasPrefix(kind) && rest.dropFirst(kind.count).first?.isWhitespace == true {
      rest = rest.dropFirst(kind.count).drop(while: \.isWhitespace)
      break
    }

    var module = rest.prefix(while: isIdentifierCharacter)
    var tail = rest.dropFirst(module.count)
    while tail.first == ".", tail.dropFirst().first.map(isIdentifierCharacter) == true {
      let component = tail.dropFirst().prefix(while: isIdentifierCharacter)
      module = rest.prefix(module.count + 1 + component.count)
      tail = tail.dropFirst(1 + component.count)
    }
    guard tail.allSatisfy(\.isWhitespace) else {
      return nil
    }
    return String(module)
  }

  /// Returns the rest of the code of a line after its `import` keyword, `nil` for code that doesn't start with one after
  /// its attributes.
  ///
  /// - Parameter code: The code of the line, without its comments.
  /// - Returns: The rest of the code, without its leading whitespace.
  private static func restAfterImportKeyword(_ code: String) -> Substring? {
    var rest = code.drop(while: \.isWhitespace)
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
      } else if !isDirective(line, "#elseif"), !isDirective(line, "#else") {
        switch lineKind(lines, at: index) {
        case .comment(let next):
          index = next
          continue
        case .import(let module):
          modules.append(module)
        case .unsupportedImport(let reason):
          return .unsupported(lineIndex: index, reason: reason)
        case .code:
          return .other
        }
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
      } else if line.drop(while: \.isWhitespace).hasPrefix("/*") {
        // a block comment with code after it is skipped with that code, so that a directive in the comment isn't counted
        index = codeSpan(lines, at: index).end + 1
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
    while next < lines.count {
      switch lineKind(lines, at: next) {
      case .comment(let after):
        next = after
      case .import,
           .unsupportedImport:
        return true
      case .code:
        return isDirective(lines[next], "#if") && importBlock(lines, from: next) != .other
      }
    }
    return false
  }

  /// Returns the lines of a text with each run of imports sorted.
  ///
  /// - Parameter text: The text.
  /// - Returns: The lines, with each run of consecutive import lines sorted.
  private static func sortingRunsOfImports(_ text: String) -> [String] {
    var lines = text.components(separatedBy: "\n")
    var start = 0
    while start < lines.count {
      guard isImport(lines, at: start) else {
        start += 1
        continue
      }
      var end = start
      while end < lines.count, isImport(lines, at: end) {
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

  /// Returns the index of the line after the blank line or the comments at a line, `nil` for a line with code.
  ///
  /// A block comment is skipped whole, as the lines in it, such as the code of a template, aren't the file's.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: The index of the line after the comments.
  private static func lineAfterComment(_ lines: [String], at index: Int) -> Int? {
    switch lineKind(lines, at: index) {
    case .comment(let next):
      return next
    case .import,
         .unsupportedImport,
         .code:
      return nil
    }
  }

  /// Returns whether a line is an import that can be grouped.
  ///
  /// - Parameters:
  ///   - lines: The file's lines.
  ///   - index: The index of the line.
  /// - Returns: Whether the line is an import.
  private static func isImport(_ lines: [String], at index: Int) -> Bool {
    switch lineKind(lines, at: index) {
    case .import:
      return true
    case .comment,
         .unsupportedImport,
         .code:
      return false
    }
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

    /// Why an import with a block comment that spans lines makes the imports unsupported, as the import can't move
    /// without the comment's other lines.
    static let importWithAMultilineCommentReason = "an import with a block comment that spans lines"
  }
}
