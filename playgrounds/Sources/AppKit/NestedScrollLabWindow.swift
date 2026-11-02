//
//  NestedScrollLabWindow.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/3/26.
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

import AppKit

import ComposeUI

/// A resizable window for the nested scroll lab.
final class NestedScrollLabWindow: NSWindowController {

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: Constants.initialSize.width, height: Constants.initialSize.height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Nested Scroll Lab"
    window.minSize = Constants.minSize
    self.init(window: window)

    let lab = NestedScrollLab(frame: window.contentLayoutRect)
    lab.autoresizingMask = [.width, .height]
    window.contentView = lab
    window.center()
  }

  // MARK: - Constants

  private enum Constants {
    static let initialSize = CGSize(width: 560, height: 780)
    static let minSize = CGSize(width: 400, height: 520)
  }
}

/// A lab for scrolling between nested scroll views.
///
/// An outer list holds inner lists that scroll along the same axis, separated by dark strips of the outer list. The log
/// at the bottom records every scroll event the window gets: its phase, its momentum phase, its vertical delta, whether
/// it comes from a device with precise deltas, such as a trackpad or a Magic Mouse, the list under the pointer, and the
/// offsets of the outer list and of that list. The log also goes to a file, whose path is its first line.
private final class NestedScrollLab: NSView {

  private lazy var outerList = ComposeView { [weak self] in
    self?.outerContent ?? Empty()
  }

  private let logLabel = NSTextField(wrappingLabelWithString: "")
  private let logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("NestedScrollLab.log")
  private var logHandle: FileHandle?
  private var recentLogLines: [String] = []
  private var eventMonitor: Any?
  private let startTime = CACurrentMediaTime()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    outerList.identifier = NSUserInterfaceItemIdentifier("outer")
    addSubview(outerList)

    logLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
    logLabel.textColor = .secondaryLabelColor
    addSubview(logLabel)

    FileManager.default.createFile(atPath: logURL.path, contents: nil)
    logHandle = try? FileHandle(forWritingTo: logURL)
    appendLog("log file: \(logURL.path)")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override func layout() {
    super.layout()

    logLabel.frame = CGRect(x: 8, y: 4, width: bounds.width - 16, height: Constants.logHeight - 8)
    outerList.frame = CGRect(x: 0, y: Constants.logHeight, width: bounds.width, height: bounds.height - Constants.logHeight)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    if window != nil {
      if eventMonitor == nil {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
          self?.record(event)
          return event
        }
      }
    } else if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
  }

  private var outerContent: ComposeContent {
    VStack {
      for index in 0 ..< Constants.innerListCount {
        LabelNode("Outer list")
          .textColor(.white)
          .frame(width: .flexible, height: Constants.stripHeight)
          .background { ColorNode(.darkGray) }

        HStack {
          // a column of the outer list beside each inner list, so the pointer can stay over the outer list while it
          // scrolls
          LabelNode("Outer")
            .textColor(.white)
            .frame(width: Constants.outerColumnWidth, height: Constants.innerListHeight)
            .background { ColorNode(.darkGray) }

          ComposeViewNode {
            VStack {
              for row in 0 ..< Constants.innerRowCount {
                LabelNode("Inner list \(index), row \(row)")
                  .frame(width: .flexible, height: Constants.rowHeight)
                  .background { ColorNode(row.isMultiple(of: 2) ? Constants.rowColor : Constants.alternateRowColor) }
              }
            }
          }
          .fixedSize(width: false, height: false)
          .onInsert { renderable, _ in
            renderable.view?.identifier = NSUserInterfaceItemIdentifier("inner \(index)")
          }
          .frame(width: .flexible, height: Constants.innerListHeight)
        }
      }
    }
  }

  private func record(_ event: NSEvent) {
    guard let window, event.window === window, let contentView = window.contentView, let frameView = contentView.superview else {
      return
    }

    let hitView = contentView.hitTest(frameView.convert(event.locationInWindow, from: nil))
    let scrollView = Self.nearestScrollView(of: hitView)
    let line = String(
      format: "%8.3f  phase %-9@ momentum %-9@ dy %8.2f  precise %@  under %-8@ outer %7.1f  under %7.1f",
      CACurrentMediaTime() - startTime,
      Self.name(of: event.phase),
      Self.name(of: event.momentumPhase),
      event.scrollingDeltaY,
      event.hasPreciseScrollingDeltas ? "yes" : "no ",
      scrollView?.identifier?.rawValue ?? "-",
      outerList.contentOffset.y,
      scrollView?.contentOffset.y ?? .nan
    )
    appendLog(line)
  }

  private func appendLog(_ line: String) {
    logHandle?.write(Data((line + "\n").utf8))
    recentLogLines.append(line)
    if recentLogLines.count > Constants.visibleLogLineCount {
      recentLogLines.removeFirst(recentLogLines.count - Constants.visibleLogLineCount)
    }
    logLabel.stringValue = recentLogLines.joined(separator: "\n")
  }

  private static func nearestScrollView(of view: NSView?) -> ScrollView? {
    var current = view
    while let candidate = current {
      if let scrollView = candidate as? ScrollView {
        return scrollView
      }
      current = candidate.superview
    }
    return nil
  }

  private static func name(of phase: NSEvent.Phase) -> String {
    switch phase {
    case []:
      return "none"
    case .mayBegin:
      return "mayBegin"
    case .began:
      return "began"
    case .stationary:
      return "stationary"
    case .changed:
      return "changed"
    case .ended:
      return "ended"
    case .cancelled:
      return "cancelled"
    default:
      return "\(phase.rawValue)"
    }
  }

  // MARK: - Constants

  private enum Constants {

    static let innerListCount = 8
    static let innerRowCount = 30
    static let innerListHeight: CGFloat = 260
    static let stripHeight: CGFloat = 80
    static let outerColumnWidth: CGFloat = 140
    static let rowHeight: CGFloat = 30
    static let logHeight: CGFloat = 110
    static let visibleLogLineCount = 7
    static let rowColor = NSColor.systemBlue.withAlphaComponent(0.25)
    static let alternateRowColor = NSColor.systemTeal.withAlphaComponent(0.25)
  }
}
