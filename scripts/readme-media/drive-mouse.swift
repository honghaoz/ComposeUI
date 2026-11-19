//
//  drive-mouse.swift
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

// Drives the real cursor with a script of steps, for recording the README "Interaction" demo.
//
// usage: drive-mouse <step>...
//
// The steps are `warp x y`, `move x y seconds` (eased), `down`, `up` and `sleep seconds`, with the coordinates in points
// from the top-left corner of the main screen.

import CoreGraphics
import Foundation

var position = CGEvent(source: nil)?.location ?? .zero
var steps = Array(CommandLine.arguments.dropFirst())

func post(_ type: CGEventType, at point: CGPoint) {
  guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
    return
  }
  if type == .leftMouseDown || type == .leftMouseUp {
    event.setIntegerValueField(.mouseEventClickState, value: 1)
  }
  event.post(tap: .cghidEventTap)
}

func easeInOut(_ t: Double) -> Double {
  t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}

func nextNumber() -> Double {
  guard !steps.isEmpty, let value = Double(steps.removeFirst()) else {
    FileHandle.standardError.write(Data("error: a step is missing a number\n".utf8))
    exit(2)
  }
  return value
}

while !steps.isEmpty {
  let step = steps.removeFirst()
  switch step {
  case "warp":
    position = CGPoint(x: nextNumber(), y: nextNumber())
    CGWarpMouseCursorPosition(position)
    post(.mouseMoved, at: position)
  case "move":
    let start = position
    let end = CGPoint(x: nextNumber(), y: nextNumber())
    let seconds = nextNumber()
    let count = max(1, Int(seconds * 120))
    for index in 1 ... count {
      let progress = easeInOut(Double(index) / Double(count))
      position = CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y + (end.y - start.y) * progress)
      post(.mouseMoved, at: position)
      usleep(UInt32(seconds / Double(count) * 1000000))
    }
  case "down":
    post(.leftMouseDown, at: position)
  case "up":
    post(.leftMouseUp, at: position)
  case "sleep":
    usleep(UInt32(nextNumber() * 1000000))
  default:
    FileHandle.standardError.write(Data("error: unknown step \(step)\n".utf8))
    exit(2)
  }
}
