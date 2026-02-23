//
//  Colors.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
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
