//
//  Colors.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
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

import ComposeUI

enum Colors {

  static let lightBlueGray = Color(hue: 214 / 360, saturation: 0.15, brightness: 0.86, alpha: 1)
  static let blueGray = Color(hue: 215 / 360, saturation: 0.4, brightness: 0.6, alpha: 1)
  static let darkBlueGray = Color(hue: 213 / 360, saturation: 0.46, brightness: 0.53, alpha: 1)

  enum RetroApple {

    static let green = Color(red: 97 / 255, green: 187 / 255, blue: 70 / 255, alpha: 1)
    static let yellow = Color(red: 253 / 255, green: 184 / 255, blue: 39 / 255, alpha: 1)
    static let orange = Color(red: 245 / 255, green: 130 / 255, blue: 31 / 255, alpha: 1)
    static let red = Color(red: 224 / 255, green: 58 / 255, blue: 62 / 255, alpha: 1)
    static let purple = Color(red: 150 / 255, green: 61 / 255, blue: 151 / 255, alpha: 1)

    static let all: [Color] = [green, yellow, orange, red, purple]
  }
}
