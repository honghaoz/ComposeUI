//
//  ImportGroupsTests.swift
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

import ChouTiTest

class ImportGroupsTests: XCTestCase {

  // MARK: - Group

  func test_group_ordersTheGroups() {
    // given: a file whose imports are out of the groups' order, with a system import after the local module and
    // an #if block after the others
    let text = """
    //
    //  FileTests.swift
    //

    import ChouTiTest

    @testable import ComposeUI
    import ChouTi
    import SwiftUI

    #if canImport(UIKit)
    import UIKit
    #endif

    class FileTests: XCTestCase {}

    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the system frameworks come first, then the external frameworks, the test frameworks and the local modules,
    // with a blank line between the groups
    expect(outcome) == .grouped("""
    //
    //  FileTests.swift
    //

    #if canImport(UIKit)
    import UIKit
    #endif
    import SwiftUI

    import ChouTi

    import ChouTiTest

    @testable import ComposeUI

    class FileTests: XCTestCase {}

    """)
  }

  func test_group_systemGroup_putsTheIfBlocksFirst_inTheOrderOfTheirModules() {
    // given: a file whose system frameworks are in three groups, with the UIKit block before the AppKit block
    let text = """
    import QuartzCore

    #if canImport(UIKit)
    import UIKit
    #endif

    #if canImport(AppKit)
    import AppKit
    #endif

    import ChouTiTest

    @_spi(Private) @testable import ComposeUI

    class A {}
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the system frameworks are one group, with the AppKit block, the UIKit block, then the other imports
    expect(outcome) == .grouped("""
    #if canImport(AppKit)
    import AppKit
    #endif
    #if canImport(UIKit)
    import UIKit
    #endif
    import QuartzCore

    import ChouTiTest

    @_spi(Private) @testable import ComposeUI

    class A {}
    """)
  }

  func test_group_ifBlocksOfTheSameModule_keepTheirOrder() {
    // given: two #if blocks that import the same module, the tvOS block before the iOS block, after another import of
    // their group
    let text = """
    import Foundation
    #if os(tvOS)
    import UIKit
    #endif
    #if os(iOS)
    import UIKit
    #endif

    class A {}
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the blocks come first, in their order, as their module doesn't order them
    expect(outcome) == .grouped("""
    #if os(tvOS)
    import UIKit
    #endif
    #if os(iOS)
    import UIKit
    #endif
    import Foundation

    class A {}
    """)
  }

  func test_group_fileWideIf_staysAboveTheImports() {
    // given: a file in an #if block, whose imports start right after the #if
    let text = """
    #if canImport(AppKit)
    import ChouTiTest
    import AppKit

    import ComposeUI

    class A {}
    #endif
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the #if stays above the imports, with a blank line after it, and its #endif has a blank line before it
    expect(outcome) == .grouped("""
    #if canImport(AppKit)

    import AppKit

    import ChouTiTest

    import ComposeUI

    class A {}

    #endif
    """)
  }

  func test_group_nestedFileWideIfs_haveOneBlankLineBeforeTheirEndifs() {
    // given: a file in two #if blocks, with three blank lines before their #endif lines
    let text = """
    #if canImport(UIKit)
    #if !os(tvOS)
    import UIKit

    class A {}



    #endif
    #endif

    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the #if lines stay together above the imports, and one blank line comes before the #endif lines
    expect(outcome) == .grouped("""
    #if canImport(UIKit)
    #if !os(tvOS)

    import UIKit

    class A {}

    #endif
    #endif

    """)
  }

  func test_group_platformSections_areLeftAlone() {
    // given: a file with a part for each platform, each in an #if block with its own imports
    let text = """
    #if canImport(AppKit)
    import AppKit

    class A {}
    #endif

    #if canImport(UIKit)
    import UIKit

    class A {}
    #endif
    """

    // then: the first #if doesn't wrap the file, so it starts the code, and the file stays as it is
    expect(ImportGroups.group(text, config: Constants.config)) == .grouped(text)
  }

  func test_group_ifWithoutItsEndif_isLeftAlone() {
    // given: a file in an #if block whose #endif is missing, with imports of different groups
    let text = """
    #if canImport(UIKit)
    import UIKit
    import ChouTiTest
    """

    // then: the #if is neither a file-wide #if nor a block of imports, so it starts the code, and the file stays as it is
    expect(ImportGroups.group(text, config: Constants.config)) == .grouped(text)
  }

  func test_group_fileWideIf_withDirectivesInACommentAndAString_endsAtItsEndif() {
    // given: a file in an #if block, with an #endif in a block comment and an #if in a multiline string literal
    let text = #"""
    #if canImport(UIKit)
    import UIKit

    /*
     #endif
     */
    let sample = """
    #if DEBUG
    """
    #endif
    """#

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the directives in the comment and the string aren't the file's, so the #if wraps the file, with a blank line
    // after it and one before its #endif
    expect(outcome) == .grouped(#"""
    #if canImport(UIKit)

    import UIKit

    /*
     #endif
     */
    let sample = """
    #if DEBUG
    """

    #endif
    """#)
  }

  func test_group_attributesSubmodulesAndDeclarations_goWithTheirModules() {
    // given: imports with attributes, of a submodule and of a declaration
    let text = """
    @_spi(Private) @testable import ComposeUI
    import ChouTiTest
    import UIKit.UIGestureRecognizerSubclass
    import struct Foundation.Date
    @preconcurrency import Combine

    class A {}
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: each goes with its module, and the system imports keep their order, which SwiftFormat sorts
    expect(outcome) == .grouped("""
    import UIKit.UIGestureRecognizerSubclass
    import struct Foundation.Date
    @preconcurrency import Combine

    import ChouTiTest

    @_spi(Private) @testable import ComposeUI

    class A {}
    """)
  }

  func test_group_codeAfterTheImports_isLeftAlone() {
    // given: an #if block of code, one after a comment, one with only a comment, an attribute of a declaration, one
    // whose arguments go on to the next lines, and a declaration after a block comment on its line, right after the
    // imports
    let ifBlock = """
    @testable import ComposeUI

    #if DEBUG
    /// The checks.
    enum Checks {}
    #endif
    """
    let ifBlockAfterAComment = """
    import ChouTiTest

    // the checks
    #if DEBUG
    enum Checks {}
    #endif
    """
    let ifBlockWithAComment = """
    import ChouTiTest

    #if DEBUG
    // the checks
    #endif
    """
    let attribute = """
    import ChouTiTest

    @MainActor
    final class A {}
    """
    let attributeOnLines = """
    import ChouTiTest

    @available(
      *, deprecated
    )
    final class A {}
    """
    let blockComment = """
    import ChouTiTest

    /* the type */ final class A {}
    """

    // then: none is an import, so the files stay as they are
    expect(ImportGroups.group(ifBlock, config: Constants.config)) == .grouped(ifBlock)
    expect(ImportGroups.group(ifBlockAfterAComment, config: Constants.config)) == .grouped(ifBlockAfterAComment)
    expect(ImportGroups.group(ifBlockWithAComment, config: Constants.config)) == .grouped(ifBlockWithAComment)
    expect(ImportGroups.group(attribute, config: Constants.config)) == .grouped(attribute)
    expect(ImportGroups.group(attributeOnLines, config: Constants.config)) == .grouped(attributeOnLines)
    expect(ImportGroups.group(blockComment, config: Constants.config)) == .grouped(blockComment)
  }

  func test_group_withoutImports_isUnchanged() {
    // given: a file without imports, and a file in an #if block without imports
    let withoutImports = """
    //
    //  A.swift
    //

    /// A type.
    enum A {}
    """
    let ifBlockWithoutImports = """
    #if DEBUG
    enum A {}
    #endif
    """

    // then: they stay as they are
    expect(ImportGroups.group(withoutImports, config: Constants.config)) == .grouped(withoutImports)
    expect(ImportGroups.group(ifBlockWithoutImports, config: Constants.config)) == .grouped(ifBlockWithoutImports)
  }

  func test_group_blankLines_areOneBetweenGroups() {
    // given: imports with two blank lines between them and three before the code, and a comment after an import
    let text = """
    import ChouTiTest


    import UIKit // for the views



    class A {}
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: one blank line separates the groups and the code, and the comment stays with its import
    expect(outcome) == .grouped("""
    import UIKit // for the views

    import ChouTiTest

    class A {}
    """)
  }

  func test_group_ifBlockWithBranches_staysWhole() {
    // given: an #if block of imports with an #elseif branch, after a test framework
    let text = """
    import ChouTiTest
    #if canImport(AppKit)
    import AppKit
    #elseif canImport(UIKit)
    import UIKit
    #endif

    class A {}
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the block moves whole to the system group
    expect(outcome) == .grouped("""
    #if canImport(AppKit)
    import AppKit
    #elseif canImport(UIKit)
    import UIKit
    #endif

    import ChouTiTest

    class A {}
    """)
  }

  func test_group_ifBlockWithAComment_movesWhole() {
    // given: an #if block of imports with a comment in it, between an external framework and a system framework
    let text = """
    import ChouTi
    #if canImport(UIKit)
    // for the gesture recognizer's subclass hooks
    import UIKit.UIGestureRecognizerSubclass
    #endif
    import Foundation

    let x = 1
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the block moves whole, with its comment, to the system group
    expect(outcome) == .grouped("""
    #if canImport(UIKit)
    // for the gesture recognizer's subclass hooks
    import UIKit.UIGestureRecognizerSubclass
    #endif
    import Foundation

    import ChouTi

    let x = 1
    """)
  }

  func test_group_ifBlockWithAnImportInABlockComment_goesWithItsImports() {
    // given: an #if block with a test framework's import in a block comment and a system framework's import, after an
    // external framework
    let text = """
    import ChouTi
    #if canImport(UIKit)
    /*
     import ChouTiTest
     */
    import UIKit
    #endif

    let x = 1
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the import in the comment doesn't count, so the block goes to the system group
    expect(outcome) == .grouped("""
    #if canImport(UIKit)
    /*
     import ChouTiTest
     */
    import UIKit
    #endif

    import ChouTi

    let x = 1
    """)
  }

  func test_group_blockCommentAfterAnImport_staysWithIt() {
    // given: an external framework with a block comment after it, before a system framework
    let text = """
    import ChouTi /* the helpers */
    import Foundation

    let x = 1
    """

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the comment stays with its import
    expect(outcome) == .grouped("""
    import Foundation

    import ChouTi /* the helpers */

    let x = 1
    """)
  }

  func test_group_fileWideIf_withQuotesInAComment_endsAtItsEndif() {
    // given: a file in an #if block, with three quotes in a documentation comment
    let text = #"""
    #if canImport(UIKit)
    import ChouTiTest
    import UIKit

    /// Use """ for a multiline string.
    let x = 1
    #endif
    """#

    // when: grouping its imports
    let outcome = ImportGroups.group(text, config: Constants.config)

    // then: the quotes in the comment don't open a string, so the #if wraps the file, and the imports are grouped
    expect(outcome) == .grouped(#"""
    #if canImport(UIKit)

    import UIKit

    import ChouTiTest

    /// Use """ for a multiline string.
    let x = 1

    #endif
    """#)
  }

  func test_group_groupedText_isUnchanged() {
    // given: files whose imports are out of order
    let texts = [
      "import ChouTiTest\nimport UIKit\n\nclass A {}\n",
      "#if canImport(UIKit)\nimport ChouTiTest\n#if canImport(SwiftUI)\nimport SwiftUI\n#endif\n\nclass A {}\n#endif\n",
      "@testable import ComposeUI\nimport ChouTi\n",
    ]

    for text in texts {
      // when: grouping the imports, then grouping the grouped imports
      let grouped: String
      switch ImportGroups.group(text, config: Constants.config) {
      case .grouped(let text):
        grouped = text
      case .unsupported(let line, let reason):
        fail("expected the imports to be grouped, unsupported at line \(line): \(reason)")
        continue
      }

      // then: grouping them again changes nothing
      expect(ImportGroups.group(grouped, config: Constants.config), text) == .grouped(grouped)
    }
  }

  func test_group_commentBetweenImports_isUnsupported() {
    // given: a comment between two imports, one with a blank line after it, one before an #if block of imports, a
    // comment between a file-wide #if and its imports, and a comment before a line with two imports
    let betweenImports = """
    import ChouTiTest
    // the views
    import UIKit

    class A {}
    """
    let withABlankLineAfterIt = """
    import ChouTiTest
    // the views

    import UIKit

    class A {}
    """
    let beforeAnIfBlock = """
    import ChouTiTest
    // the views
    #if canImport(UIKit)
    import UIKit
    #endif

    class A {}
    """
    let afterTheIf = """
    #if canImport(UIKit)
    // the views
    import UIKit

    class A {}
    #endif
    """
    let beforeTwoImports = """
    import ComposeUI
    // the helpers
    import ChouTi; import ChouTiTest

    let x = 1
    """

    // then: the imports can't be grouped, as the comment's place is unknown
    expect(ImportGroups.group(betweenImports, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
    expect(ImportGroups.group(withABlankLineAfterIt, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
    expect(ImportGroups.group(beforeAnIfBlock, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
    expect(ImportGroups.group(afterTheIf, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
    expect(ImportGroups.group(beforeTwoImports, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
  }

  func test_group_blockComments_areLeftAlone() {
    // given: a template in a block comment, whose imports are out of the groups' order, a block comment between the
    // imports and the code, and a block comment that doesn't end, with an import in it, after the imports
    let template = """
    /// A template.

    /**

     import ComposeUI

     #if canImport(UIKit)
     import UIKit
     #endif

     public struct A {}
     */
    """
    let afterTheImports = """
    import ChouTiTest
    import UIKit

    /*
     The views.
     */
    class A {}
    """
    let unended = """
    import UIKit

    import ChouTiTest

    /* the old imports:
    import Foundation
    """

    // then: the template stays as it is, the block comment stays with the code, and the one that doesn't end goes on
    // to the end of the file, with its import
    expect(ImportGroups.group(template, config: Constants.config)) == .grouped(template)
    expect(ImportGroups.group(unended, config: Constants.config)) == .grouped(unended)
    expect(ImportGroups.group(afterTheImports, config: Constants.config)) == .grouped("""
    import UIKit

    import ChouTiTest

    /*
     The views.
     */
    class A {}
    """)
  }

  func test_group_blockCommentBetweenImports_isUnsupported() {
    // given: a block comment between two imports
    let text = """
    import ChouTiTest
    /*
     The views.
     */
    import UIKit

    class A {}
    """

    // then: the imports can't be grouped, as the comment's place is unknown
    expect(ImportGroups.group(text, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
  }

  func test_group_lineWithMoreThanAnImport_isUnsupported() {
    // given: two imports on the first line, an import and a declaration on the line after an import, and two imports
    // with a block comment between them
    let twoImports = """
    import ChouTi; import ChouTiTest
    import Foundation

    let x = 1
    """
    let importAndCode = """
    import Foundation
    import ChouTi; let x = 1
    """
    let blockCommentBetween = """
    import Foundation
    import ChouTi /* the helpers */; import ChouTiTest
    """

    // then: the imports can't be grouped, as the things on a line can belong in different places
    expect(ImportGroups.group(twoImports, config: Constants.config)) == .unsupported(line: 1, reason: "a line with more than an import and a comment")
    expect(ImportGroups.group(importAndCode, config: Constants.config)) == .unsupported(line: 2, reason: "a line with more than an import and a comment")
    expect(ImportGroups.group(blockCommentBetween, config: Constants.config)) == .unsupported(line: 2, reason: "a line with more than an import and a comment")
  }

  func test_group_lineWithMoreThanAnImport_inAnIfBlock_isUnsupported() {
    // given: an #if block with two imports on a line, and one with an import whose block comment goes on to the next
    // line, before other imports
    let twoImports = """
    #if canImport(UIKit)
    import UIKit; import SwiftUI
    #endif
    import ComposeUI
    import Foundation

    let x = 1
    """
    let commentOnTwoLines = """
    import ComposeUI
    #if canImport(UIKit)
    import UIKit /* the views,
     and more */
    #endif
    import Foundation

    let x = 1
    """

    // then: the imports can't be grouped, as for a line outside an #if block
    expect(ImportGroups.group(twoImports, config: Constants.config)) == .unsupported(line: 2, reason: "a line with more than an import and a comment")
    expect(ImportGroups.group(commentOnTwoLines, config: Constants.config)) == .unsupported(line: 3, reason: "a line with more than an import and a comment")
  }

  func test_group_importAfterABlockComment_isUnsupported() {
    // given: an import after a block comment on its line, after an import, on the last line of a block comment that
    // starts on an earlier line, in an #if block before another import, and after a line comment
    let afterAnImport = """
    import ComposeUI
    /* the views */ import UIKit

    let x = 1
    """
    let onTheLastLine = """
    import ComposeUI
    /* the views,
     and more */ import UIKit

    let x = 1
    """
    let inAnIfBlock = """
    import ComposeUI
    #if canImport(UIKit)
    /* the views */ import UIKit
    #endif
    import Foundation

    let x = 1
    """
    let afterALineComment = """
    import ComposeUI
    // the views
    /* the views */ import UIKit

    let x = 1
    """

    // then: the imports can't be grouped, as the comment before the import can belong to the lines before it, like a
    // comment between imports
    expect(ImportGroups.group(afterAnImport, config: Constants.config)) == .unsupported(line: 2, reason: "an import after a block comment on its line")
    expect(ImportGroups.group(onTheLastLine, config: Constants.config)) == .unsupported(line: 3, reason: "an import after a block comment on its line")
    expect(ImportGroups.group(inAnIfBlock, config: Constants.config)) == .unsupported(line: 3, reason: "an import after a block comment on its line")
    expect(ImportGroups.group(afterALineComment, config: Constants.config)) == .unsupported(line: 2, reason: "a comment between imports")
  }

  func test_group_ifBlockOfModulesOfDifferentGroups_isUnsupported() {
    // given: an #if block that imports a system framework and a test framework
    let text = """
    import ComposeUI

    #if canImport(UIKit)
    import UIKit
    import ChouTiTest
    #endif

    class A {}
    """

    // then: the imports can't be grouped, as the block belongs in two groups
    expect(ImportGroups.group(text, config: Constants.config)) == .unsupported(line: 3, reason: "an #if block that imports modules of different groups")
  }

  // MARK: - Same Groups

  func test_hasSameGroups() {
    // given: grouped imports
    let grouped = """
    import QuartzCore
    import UIKit

    import ChouTiTest

    class A {}
    """

    // then: imports in another order in a group are in the same groups, and an import in another group isn't
    expect(ImportGroups.hasSameGroups("import UIKit\nimport QuartzCore\n\nimport ChouTiTest\n\nclass A {}", as: grouped)) == true
    expect(ImportGroups.hasSameGroups("import QuartzCore\n\nimport ChouTiTest\nimport UIKit\n\nclass A {}", as: grouped)) == false
  }

  // MARK: - Config

  func test_config_parsing() throws {
    // given: a configuration with comments, two lines of paths and an excluded path
    let text = """
    # the test targets
    paths: Tests HostedTests
    paths: More # more tests
    exclude: Tests/_Deprecated

    group: *
    group: ChouTi
    group: ChouTiTest  XCTest
    group: ComposeUI
    """

    // when: parsing it
    let config = try ImportGroups.Config(parsing: text)

    // then: it has the paths, the excluded path and the groups in order, with the first for the other modules
    expect(config) == ImportGroups.Config(
      groups: [[], ["ChouTi"], ["ChouTiTest", "XCTest"], ["ComposeUI"]],
      otherModulesGroup: 0,
      paths: ["Tests", "HostedTests", "More"],
      excludedPaths: ["Tests/_Deprecated"]
    )
  }

  func test_config_parsing_errors() {
    // then: each mistake throws an error that names it
    let cases: [(text: String, error: String)] = [
      ("paths: Tests\ngroup ChouTi", "line 2: expected a key and its values, as `key: values`"),
      ("paths: Tests\ngroup: *\ngroup: *", "line 3: a second group for the modules that no group lists"),
      ("paths: Tests\ngroup:", "line 2: a group lists its modules, or is `*` alone"),
      ("paths: Tests\ngroup: ChouTi *", "line 2: a group lists its modules, or is `*` alone"),
      ("paths: Tests\ngroup: ChouTi\ngroup: ChouTi", "line 3: ChouTi is in two groups"),
      ("paths: Tests\norder: ChouTi", "line 2: unknown key `order`"),
      ("paths: Tests\ngroup: ChouTi", "no `group: *` for the modules that no group lists"),
      ("group: *", "no `paths` to apply the groups to"),
    ]
    for (text, error) in cases {
      expect(try ImportGroups.Config(parsing: text), text).to(throwError(ImportGroups.ConfigError(error)))
    }
  }

  func test_config_groupOfAModule() {
    // then: a listed module goes in its group, a submodule with its module, and another module in the group for them
    expect(Constants.config.group(of: "ChouTiTest")) == 2
    expect(Constants.config.group(of: "ComposeUI")) == 3
    expect(Constants.config.group(of: "UIKit.UIGestureRecognizerSubclass")) == 0
    expect(Constants.config.group(of: "QuartzCore")) == 0
  }

  // MARK: - Constants

  private enum Constants {

    /// The groups: system frameworks, external frameworks, test frameworks and local modules.
    static let config = ImportGroups.Config(
      groups: [[], ["ChouTi"], ["ChouTiTest", "XCTest"], ["ComposeUI"]],
      otherModulesGroup: 0,
      paths: ["Tests"],
      excludedPaths: []
    )
  }
}
