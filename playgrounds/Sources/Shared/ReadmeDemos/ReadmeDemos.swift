//
//  ReadmeDemos.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/26.
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

#if canImport(AppKit)

import AppKit

import ComposeUI

/// Shows one README demo in a borderless window, for capturing the README media.
///
/// Launch the AppKit playground with `-readmeDemo <name>`, and `-readmeTheme dark` for the dark appearance. The window
/// sits at `Constants.origin`, in points from the top-left corner of the main screen, so that a script can capture it
/// with `screencapture -R`.
enum ReadmeDemos {

  /// Opens the demo that the launch arguments ask for.
  ///
  /// - Returns: The demo window, or `nil` if the launch arguments ask for no demo.
  static func openIfRequested() -> NSWindow? {
    guard let name = UserDefaults.standard.string(forKey: "readmeDemo"), let demo = demo(named: name) else {
      return nil
    }
    let isDark = UserDefaults.standard.string(forKey: "readmeTheme") == "dark"

    let screenFrame = NSScreen.screens[0].frame
    let window = DemoWindow(
      contentRect: CGRect(
        x: Constants.origin.x,
        y: screenFrame.maxY - Constants.origin.y - demo.size.height,
        width: demo.size.width,
        height: demo.size.height
      ),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    window.level = .floating
    window.isReleasedWhenClosed = false
    window.backgroundColor = isDark ? Constants.darkCanvas : Constants.lightCanvas

    let canvas = NSView(frame: CGRect(origin: .zero, size: demo.size))
    window.contentView = canvas

    // the background is themed, so that it animates with the demo when the dark mode demo switches the appearance
    let background = ComposeView {
      ColorNode(ThemedColor(light: Constants.lightCanvas, dark: Constants.darkCanvas))
        .animation(.easeInEaseOut())
    }
    background.frame = canvas.bounds
    background.autoresizingMask = [.width, .height]
    canvas.addSubview(background)

    let view = demo.make()
    view.frame = canvas.bounds.insetBy(dx: demo.inset, dy: 0)
    view.autoresizingMask = [.width, .height]
    canvas.addSubview(view)

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)

    demo.start(view)
    return window
  }

  private static func demo(named name: String) -> Demo? {
    switch name {
    case "layout":
      return Demo(make: { LayoutDemoView() })
    case "styling":
      return Demo(make: { StylingDemoView() })
    case "text":
      return Demo(make: { TextDemoView() }, start: selectWord)
    case "animations":
      return Demo(make: { AnimationDemoView() }, start: { view in
        repeatEvery(1.5) { (view as? AnimationDemoView)?.toggle() }
      })
    case "transitions":
      return Demo(make: { TransitionDemoView() }, start: { view in
        alternate(first: 1.6, second: 0.9) {
          guard let view = view as? TransitionDemoView else {
            return
          }
          view.isShown.toggle()
          view.refresh()
        }
      })
    case "interaction":
      return Demo(make: { InteractionDemoView() })
    case "dark-mode":
      return Demo(make: { DarkModeDemoView() }, start: { view in
        repeatEvery(Constants.themeInterval) {
          guard let window = view.window else {
            return
          }
          let isDark = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
          window.appearance = NSAppearance(named: isDark ? .aqua : .darkAqua)
        }
      })
    case "interop":
      return Demo(make: { InteropDemoView() })
    case "scrolling":
      return Demo(size: Constants.tallSize, inset: 0, make: { ScrollingDemoView() }, start: flingDownAndBack)
    default:
      return nil
    }
  }

  // MARK: - Auto Play

  private static func repeatEvery(_ interval: TimeInterval, _ block: @escaping () -> Void) {
    // a common mode timer keeps firing while the app tracks the mouse
    let timer = Timer(timeInterval: interval, repeats: true) { _ in block() }
    RunLoop.main.add(timer, forMode: .common)
  }

  /// Runs the block after `first` seconds, then after `second` seconds, and so on, forever.
  private static func alternate(first: TimeInterval, second: TimeInterval, _ block: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + first) {
      block()
      alternate(first: second, second: first, block)
    }
  }

  /// Selects a word in the demo's text view, so that the capture shows that the text is selectable.
  private static func selectWord(in view: ComposeView) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      guard let textView = firstSubview(of: NSTextView.self, in: view) else {
        return
      }
      let range = (textView.string as NSString).range(of: "selectable")
      view.window?.makeFirstResponder(textView)
      textView.setSelectedRange(range)
    }
  }

  /// Flings the demo down the list and back to the top, forever.
  private static func flingDownAndBack(_ view: ComposeView) {
    let distance = Constants.scrollDistance
    let duration = Constants.scrollDuration
    let pause = Constants.scrollPause
    let period = 2 * (duration + pause)
    let start = CACurrentMediaTime()

    let update = { (now: CFTimeInterval) in
      let time = (now - start).truncatingRemainder(dividingBy: period)
      let progress: CGFloat
      if time < pause {
        progress = 0
      } else if time < pause + duration {
        progress = flingCurve((time - pause) / duration)
      } else if time < 2 * pause + duration {
        progress = 1
      } else {
        progress = 1 - flingCurve((time - 2 * pause - duration) / duration)
      }
      view.contentOffset = CGPoint(x: 0, y: distance * progress)
      // the scroll indicator stays shown, since the overlay scroller fading in holds up the window's frames for about
      // 0.2 s, which shows as a stutter when it fades in during a fast fling
      view.flashScrollers()
    }

    // a display link sets the offset once per frame, for the time that the frame shows, so that each frame scrolls by
    // its own step, while a timer drifts against the display and leaves some frames without a new offset
    if #available(macOS 14.0, *) {
      // `-readmeFrameHold n` shows each frame of the scroll for n display frames, so that a capture gets every frame of
      // it even when the window misses a display frame, and the capture is sped up afterwards. `-readmeFrameRate` sets
      // the frame rate of the scroll's frames, 60 by default
      let hold = UserDefaults.standard.integer(forKey: "readmeFrameHold")
      let frameRate = UserDefaults.standard.double(forKey: "readmeFrameRate")
      var displayFrame = 0
      let target = DisplayLinkTarget { now in
        if hold > 0 {
          update(start + Double(displayFrame / hold) / (frameRate > 0 ? frameRate : 60))
          displayFrame += 1
        } else {
          update(now)
        }
      }
      let link = view.displayLink(target: target, selector: #selector(DisplayLinkTarget.step(_:)))
      link.add(to: .main, forMode: .common)
    } else {
      let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { _ in update(CACurrentMediaTime()) }
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  /// Returns the progress of a fling at a time from 0 to 1.
  ///
  /// The speed peaks at a quarter of the time and then slows down to a stop, as a scroll view's momentum does, so that
  /// the list moves fast without a sudden start or stop.
  private static func flingCurve(_ t: Double) -> CGFloat {
    CGFloat(10 * pow(t, 2) - 20 * pow(t, 3) + 15 * pow(t, 4) - 4 * pow(t, 5))
  }

  private static func firstSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
    for subview in view.subviews {
      if let match = subview as? T ?? firstSubview(of: type, in: subview) {
        return match
      }
    }
    return nil
  }

  // MARK: - Types

  /// The target of a display link, which calls a block with the time that each frame shows.
  private final class DisplayLinkTarget: NSObject {

    private let block: (CFTimeInterval) -> Void

    init(_ block: @escaping (CFTimeInterval) -> Void) {
      self.block = block
    }

    @available(macOS 14.0, *)
    @objc func step(_ link: CADisplayLink) {
      block(link.targetTimestamp)
    }
  }

  private struct Demo {

    let size: CGSize
    let inset: CGFloat
    let make: () -> ComposeView
    let start: (ComposeView) -> Void

    init(size: CGSize = Constants.size,
         inset: CGFloat = Constants.inset,
         make: @escaping () -> ComposeView,
         start: @escaping (ComposeView) -> Void = { _ in })
    {
      self.size = size
      self.inset = inset
      self.make = make
      self.start = start
    }
  }

  /// A borderless window that can become key, so that a text selection shows in the active color.
  private final class DemoWindow: NSWindow {

    override var canBecomeKey: Bool { true }
  }

  // MARK: - Constants

  private enum Constants {

    static let origin = CGPoint(x: 120, y: 160)
    static let size = CGSize(width: 360, height: 220)
    static let tallSize = CGSize(width: 360, height: 360)
    static let inset: CGFloat = 20

    static let lightCanvas = NSColor(srgbRed: 0.949, green: 0.949, blue: 0.969, alpha: 1)
    static let darkCanvas = NSColor.black

    static let scrollDistance: CGFloat = 8400
    static let scrollDuration: TimeInterval = 3
    static let scrollPause: TimeInterval = 0.8

    static let themeInterval: TimeInterval = 1.6
  }
}

#endif
