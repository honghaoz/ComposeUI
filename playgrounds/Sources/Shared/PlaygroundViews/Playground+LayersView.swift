//
//  Playground+LayersView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/21/25.
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
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

  final class LayersView: AnimatingComposeView {

    @ComposeContentBuilder
    override var content: ComposeContent {
      VStack {
        HStack {
          LabelNode("Awesome CALayer")
            .font(.systemFont(ofSize: 18, weight: .medium))
            .shadow(color: .black, opacity: 0.5, radius: 1, offset: CGSize(width: 1, height: 1), path: nil)
          Spacer()
        }

        Spacer(height: 32)

        HStack {
          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 3 // 0.33333

              layer.cornerRadius = 20

              layer.setValue(-3, forKey: "borderOffset")
            }
            .frame(100)

          Spacer(width: 32)

          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 3 // 0.33333

              layer.cornerRadius = 20

              layer.setValue(0.333333 * 2, forKey: "borderOffset")

              layer.setValue(true, forKey: "softRim")
              layer.setValue(20, forKey: "rimWidth")
              layer.setValue(Color.green.cgColor, forKey: "rimColor")
              layer.setValue(1, forKey: "rimOpacity")
            }
            .frame(100)

          Spacer(width: 32)

          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 3 // 0.33333

              layer.cornerRadius = 20

              layer.setValue(0.333333 * 2, forKey: "borderOffset")

              layer.setValue(false, forKey: "softRim")
              layer.setValue(20, forKey: "rimWidth")
              layer.setValue(Color.green.cgColor, forKey: "rimColor")
              layer.setValue(1, forKey: "rimOpacity")
            }
            .frame(100)
        }

        Spacer(height: 48)

        HStack {
          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 3 // 0.33333

              // layer.masksToBounds = true
              // layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

              // zero cornerRadii will respect cornerRadius
              layer.cornerRadius = 20
              layer.cornerRadii = CACornerRadii(
                topLeft: CGSize(width: 0, height: 0),
                topRight: CGSize(width: 0, height: 0),
                bottomLeft: CGSize(width: 0, height: 0),
                bottomRight: CGSize(width: 0, height: 0)
              )
            }
            .frame(100)

          Spacer(width: 32)

          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 3 // 0.33333

              layer.cornerRadius = 20
              layer.cornerCurve = .continuous

              layer.cornerRadii = CACornerRadii(
                topLeft: CGSize(width: 50, height: 10),
                topRight: CGSize(width: 60, height: 50),
                bottomLeft: CGSize(width: 20, height: 40),
                bottomRight: CGSize(width: 30, height: 20)
              )
            }
            .frame(100)

          Spacer(width: 32)

          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 6 // 0.33333

              layer.cornerRadius = 20
              layer.cornerCurve = .continuous
              // layer.setValue(true, forKey: "continuousCorners")

              layer.setValue(-0.333333 * 20, forKey: "borderOffset")

              layer.cornerRadii = CACornerRadii(
                topLeft: CGSize(width: 50, height: 10),
                topRight: CGSize(width: 60, height: 50),
                bottomLeft: CGSize(width: 20, height: 40),
                bottomRight: CGSize(width: 30, height: 20)
              )
            }
            .frame(100)

          Spacer(width: 32)

          LayerNode()
            .onUpdate { renderable, _ in
              let layer = renderable.layer

              layer.backgroundColor = Color.red.cgColor

              layer.borderColor = Color.yellow.cgColor
              layer.borderWidth = 6 // 0.33333

              layer.cornerRadius = 20
              layer.cornerCurve = .continuous
              // layer.setValue(true, forKey: "continuousCorners")
              // layer.setValue(true, forKey: "flipsHorizontalAxis")
              // layer.isGeometryFlipped = true
              // layer.setValue(true, forKey: "shouldFlatten")
              // layer.setValue(true, forKey: "shouldReflatten")
              // layer.setValue(CGSize(width: 50, height: 50), forKey: "margin")

              layer.setValue(0.333333 * 30, forKey: "borderOffset")

              layer.cornerRadii = CACornerRadii(
                topLeft: CGSize(width: 50, height: 10),
                topRight: CGSize(width: 60, height: 50),
                bottomLeft: CGSize(width: 20, height: 40),
                bottomRight: CGSize(width: 30, height: 20)
              )

              // layer.shadowColor = Color.black.cgColor
              // layer.shadowOpacity = 0.5
              // layer.shadowOffset = CGSize(width: 4, height: 4)
              // layer.shadowRadius = 1
              // layer.setValue(true, forKey: "punchoutShadow")
            }
            .frame(100)
        }

        Spacer()
      }
      .padding(16)
    }

    override func animate() {}
  }
}

import QuartzCore
import CoreGraphics

struct CACornerRadii {
  var topLeft: CGSize
  var topRight: CGSize
  var bottomLeft: CGSize
  var bottomRight: CGSize
}

private extension CALayer {

  var cornerRadii: CACornerRadii {
    get {
      guard let value = value(forKey: "cornerRadii") as? NSValue else {
        // return default if no value is set
        return CACornerRadii(topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero)
      }

      // safely extract bytes from NSValue
      let expectedSize = MemoryLayout<CACornerRadii>.size
      var buffer = [UInt8](repeating: 0, count: expectedSize)

      value.getValue(&buffer)

      // convert bytes back to CACornerRadii
      return buffer.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
          print("Warning: Unable to read CACornerRadii bytes from NSValue")
          return CACornerRadii(topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero)
        }
        return baseAddress.load(as: CACornerRadii.self)
      }
    }

    set {
      // // CACornerRadii is a struct of 4 CGSize (each = 2 Doubles = 16 bytes)
      // // so total size = 4 * 16 = 64 bytes
      // var rawBytes = [UInt8](repeating: 0, count: 64)

      // func writeCGSize(_ size: CGSize, to offset: Int) {
      //   let width = size.width.bitPattern.littleEndian
      //   let height = size.height.bitPattern.littleEndian

      //   withUnsafeBytes(of: width) { widthPtr in
      //     for i in 0..<8 {
      //       rawBytes[offset + i] = widthPtr[i]
      //     }
      //   }

      //   withUnsafeBytes(of: height) { heightPtr in
      //     for i in 0..<8 {
      //       rawBytes[offset + 8 + i] = heightPtr[i]
      //     }
      //   }
      // }

      // writeCGSize(newValue.bottomLeft, to: 0)
      // writeCGSize(newValue.bottomRight, to: 16)
      // writeCGSize(newValue.topRight, to: 32)
      // writeCGSize(newValue.topLeft, to: 48)

      // // Create NSValue from raw bytes
      // let data = Data(rawBytes)
      // let value = data.withUnsafeBytes {
      //   NSValue(bytes: $0.baseAddress!, objCType: "{CACornerRadii={CGSize=dd}{CGSize=dd}{CGSize=dd}{CGSize=dd}}")
      // }

      // // set via KVC
      // setValue(value, forKey: "cornerRadii")

      // ================================

      // create NSValue directly from the struct using withUnsafeBytes
      let value: NSValue = withUnsafeBytes(of: newValue) { bytes in
        guard let baseAddress = bytes.baseAddress else {
          // this should never happen with a stack-allocated struct, but for safety:
          print("Warning: Unable to create NSValue from CACornerRadii bytes")
          return NSValue()
        }
        return NSValue(bytes: baseAddress, objCType: "{CACornerRadii={CGSize=dd}{CGSize=dd}{CGSize=dd}{CGSize=dd}}")
      }

      // set via KVC
      setValue(value, forKey: "cornerRadii")
    }
  }
}
