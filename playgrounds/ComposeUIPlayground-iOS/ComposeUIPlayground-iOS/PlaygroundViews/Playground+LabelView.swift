//
//  Playground+LabelView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/21/25.
//

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ComposeUI
import SwiftUI

extension Playground {

    final class LabelView: AnimatingComposeView {

        private let alignments: [NSTextAlignment] = [
            .left,
            .center,
            .right,
            .justified,
            .natural,
        ]

        private let lineBreakModes: [NSLineBreakMode] = [
            .byWordWrapping,
            .byCharWrapping,
            .byClipping,
            .byTruncatingTail,
            .byTruncatingMiddle,
            .byTruncatingHead,
        ]

        @ComposeContentBuilder
        override var content: ComposeContent {
            VStack(spacing: 10) {
                // single line, enough width, custom font
                HStack(spacing: 10) {
                    for alignment in alignments {
                        Label("ComposéUI")
                            .font(Font(name: "HelveticaNeue", size: 13)!) // swiftlint:disable:this force_unwrapping
                            .numberOfLines(1)
                            .textAlignment(alignment)
                    }
                }
                .mapChildren {
                    $0.underlay { ColorNode(.red) }.width(100).border()
                }

                // single line, enough width, system font
                HStack(spacing: 10) {
                    for alignment in alignments {
                        Label("ComposéUI")
                            .font(.systemFont(ofSize: 13))
                            .numberOfLines(1)
                            .textAlignment(alignment)
                    }
                }
                .mapChildren {
                    $0.underlay { ColorNode(.red) }.width(100).border()
                }

                // single line with newline, enough width, custom font
                HStack(spacing: 10) {
                    for alignment in alignments {
                        Label("ComposéUI\nHello")
                            .font(Font(name: "HelveticaNeue", size: 13) ?? .systemFont(ofSize: 13))
                            .numberOfLines(1)
                            .textAlignment(alignment)
                            .lineBreakMode(.byClipping)
                    }
                }
                .mapChildren {
                    $0.underlay { ColorNode(.red) }.width(100).border()
                }

                Spacer(height: 16)

                // single line, not enough width
                HStack(spacing: 10) {
                    for alignment in alignments {
                        VStack(spacing: 10) {
                            for lineBreakMode in lineBreakModes {
                                Label("ComposéUI")
                                    .textColor(ThemedColor(light: ComposeUI.Color.black.withAlphaComponent(0.8), dark: ComposeUI.Color.white.withAlphaComponent(0.8)))
                                    .font(.systemFont(ofSize: 12))
                                    .fixedSize(width: false, height: true) // make width flexible so that the container can set the width
                                    .numberOfLines(1)
                                    .textAlignment(alignment)
                                    .lineBreakMode(lineBreakMode)
                            }
                        }
                        .mapChildren {
                            $0.underlay { ColorNode(.red) }.width(50).border()
                        }
                    }
                }

                Spacer(height: 16)

                // single line with newline, not enough width
                HStack(spacing: 10) {
                    for alignment in alignments {
                        VStack(spacing: 10) {
                            for lineBreakMode in lineBreakModes {
                                Label("ComposéUI\nHello")
                                    .textColor(ThemedColor(light: ComposeUI.Color.black.withAlphaComponent(0.8), dark: ComposeUI.Color.white.withAlphaComponent(0.8)))
                                    .font(.systemFont(ofSize: 12))
                                    .fixedSize(width: false, height: true) // make width flexible so that the container can set the width
                                    .numberOfLines(1)
                                    .textAlignment(alignment)
                                    .lineBreakMode(lineBreakMode)
                            }
                        }
                        .mapChildren {
                            $0.underlay { ColorNode(.red) }.width(50).border()
                        }
                    }
                }

                Spacer(height: 16)

                for (i, numberOfLines) in [0, 2].enumerated() {
                    VStack(spacing: 10) {
                        for lineBreakMode in lineBreakModes {
                            HStack(alignment: .top, spacing: 10) {
                                for alignment in alignments {
                                    Label("Building UI using UIKit/AppKit with declarative syntax")
                                        .font(.systemFont(ofSize: 12))
                                        .numberOfLines(numberOfLines)
                                        .textAlignment(alignment)
                                        .lineBreakMode(lineBreakMode)
                                }
                            }
                            .mapChildren { $0.width(100).border() }
                        }
                    }

                    if i == 0 {
                        Spacer(height: 16)
                    }
                }

                Spacer(height: 16)

                Label("selectable text")
                    .selectable()
                    .frame(width: 200, height: 50)

                Spacer(height: 16)

                SwiftUIViewNode {
                    if #available(macOS 12.0, iOS 15.0, *) {
                        AnyView(
                            Text("SwiftUI Text")
                                .textSelection(.enabled)
                        )
                    } else {
                        AnyView(EmptyView())
                    }
                }
                .frame(width: .flexible, height: 120)

                HStack(spacing: 32) {
                    Label("★ Rate Us")
                        .font(.boldSystemFont(ofSize: 14))
                        .textBackgroundColor(ThemedColor(ComposeUI.Color.red.withAlphaComponent(0.2)))
                        .border()

                    Label("★ Rate Us")
                        .font(Font(name: "HelveticaNeue-Bold", size: 14)!) // swiftlint:disable:this force_unwrapping
                        .textBackgroundColor(ThemedColor(ComposeUI.Color.red.withAlphaComponent(0.2)))
                        .border()
                }

                Spacer(height: 16)
            }
            .mapChildren { node in
                guard !(node is HorizontalStack), !(node is VerticalStack), !(node is SpacerNode) else {
                    return node
                }

                return node.border()
            }
        }
    }
}

private extension ComposeNode {

    func border() -> some ComposeNode {
        self.underlay {
            LayerNode()
                .border(color: Color.red.withAlphaComponent(0.5), width: 1)
        }
    }
}
