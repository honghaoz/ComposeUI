//
//  UniversalTypes.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
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

public typealias Window = NSWindow
public typealias View = NSView
public typealias TextView = NSTextView
public typealias Color = NSColor
public typealias Font = NSFont
public typealias FontDescriptor = NSFontDescriptor
public typealias EdgeInsets = NSEdgeInsets
public typealias BezierPath = NSBezierPath
public typealias GestureRecognizer = NSGestureRecognizer
public typealias GestureRecognizerDelegate = NSGestureRecognizerDelegate
public typealias TapGestureRecognizer = NSClickGestureRecognizer
public typealias PressGestureRecognizer = NSPressGestureRecognizer
public typealias PanGestureRecognizer = NSPanGestureRecognizer

/// DEPRECATED: Use `TextView` instead.
// public typealias Label = NSLabel
#endif

#if canImport(UIKit)
import UIKit

public typealias Window = UIWindow
public typealias View = UIView
public typealias TextView = UITextView
public typealias Color = UIColor
public typealias Font = UIFont
public typealias FontDescriptor = UIFontDescriptor
public typealias EdgeInsets = UIEdgeInsets
public typealias BezierPath = UIBezierPath
public typealias GestureRecognizer = UIGestureRecognizer
public typealias GestureRecognizerDelegate = UIGestureRecognizerDelegate
public typealias TapGestureRecognizer = UITapGestureRecognizer
public typealias PressGestureRecognizer = UILongPressGestureRecognizer
public typealias PanGestureRecognizer = UIPanGestureRecognizer

/// DEPRECATED: Use `TextView` instead.
// public typealias Label = UILabel
#endif
