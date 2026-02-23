//
//  Playground+Button.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/7/25.
//

#if canImport(AppKit)
import AppKit
import Carbon.HIToolbox.Events
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

extension Playground {

  final class Button: AnimatingComposeView {

    @ComposeContentBuilder
    override var content: ComposeContent {
      HStack(spacing: 16) {
        DownloadButton(hasDoubleTap: false)
        DownloadButton(hasDoubleTap: true)

        ButtonNode(
          content: { state in
            LabelNode("\(state)")
              .frame(width: 88, height: 44)
              .underlay {
                LayerNode()
                  .border(color: ThemedColor(light: .black, dark: .white), width: Themed<CGFloat>(1))
              }
          },
          onTap: {}
        )
        .shouldPerformKeyEquivalent { event in
          event.keyCode == UInt16(kVK_UpArrow) && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.numericPad, .function]
        }
      }
    }
  }
}

// MARK: - Constants

private enum Constants {

  static let cornerRadius: CGFloat = 8
  static let backgroundColor = Color(red: 50 / 255, green: 142 / 255, blue: 204 / 255, alpha: 1)
  static let hoverBackgroundColor = Color(red: 100 / 255, green: 142 / 255, blue: 204 / 255, alpha: 1)
  // static let borderColor = Color(red: 51 / 255, green: 124 / 255, blue: 172 / 255, alpha: 1)
  static let borderColor = Color(white: 0, alpha: 0.2)
}

// MARK: - Download Button

func DownloadButton(hasDoubleTap: Bool) -> ComposeNode {
  ButtonNode { state in

    let node: ComposeNode
    switch state {
    case .normal,
         .hovered:
      node = ColorNode(state == .hovered ? Constants.hoverBackgroundColor : Constants.backgroundColor)
        .cornerRadius(Constants.cornerRadius)
        .border(color: Constants.borderColor, width: 1)
        .overlay {
          ZStack {
            InnerShadowNode(color: .white, opacity: 0.3, radius: 0, offset: CGSize(width: 0, height: 1)) { renderable in
              let size = renderable.frame.size
              let cornerRadius: CGFloat = Constants.cornerRadius - 1
              return CGPath(
                roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
              )
            }

            InnerShadowNode(color: .white, opacity: 0.1, radius: 0, offset: CGSize(width: 0, height: -1)) { renderable in
              let size = renderable.frame.size
              let cornerRadius: CGFloat = Constants.cornerRadius - 1
              return CGPath(
                roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
              )
            }

            InnerShadowNode(color: .white, opacity: 0.1, radius: 1, offset: CGSize(width: 0, height: 0)) { renderable in
              let size = renderable.frame.size
              let cornerRadius: CGFloat = Constants.cornerRadius - 1
              return CGPath(
                roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
              )
            }
          }
          .padding(1)
        }

    case .pressed,
         .selected:
      node = ColorNode(Constants.backgroundColor)
        .cornerRadius(Constants.cornerRadius)
        .border(color: Constants.borderColor, width: 1)

    case .disabled:
      node = ColorNode(Colors.lightBlueGray)
    }

    node.overlay {
      Text(
        "Download",
        font: .systemFont(ofSize: NSFont.systemFontSize),
        foregroundColor: ThemedColor(Color.white),
        shadow: Themed<NSShadow>({
          let shadow = NSShadow()
          shadow.shadowColor = Color.black.withAlphaComponent(0.33)
          shadow.shadowBlurRadius = 0
          shadow.shadowOffset = CGSize(width: 0, height: -1)
          return shadow
        }())
      )
      .numberOfLines(1)
      .selectable(false)
      .fixedSize()
    }
  } onTap: {
    print("tap")
  }
  .if(hasDoubleTap) {
    $0.onDoubleTap {
      print("double tap")
    }
  }
  .shouldPerformKeyEquivalent { event in
    event.keyCode == UInt16(kVK_DownArrow) && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.numericPad, .function]
  }
  .frame(width: 88, height: 44)
}
