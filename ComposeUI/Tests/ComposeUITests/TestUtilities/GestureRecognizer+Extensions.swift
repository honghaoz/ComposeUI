//
//  File.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/8/26.
//

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@testable import ComposeUI

extension GestureRecognizer {

  private static var subclassKey: UInt8 = 0
  private static var locationInViewBlockKey: UInt8 = 0
  private static var stateBlockKey: UInt8 = 0

  /// Mock `location(in:)`, `state`.
  func override(locationInView: @escaping (View?) -> CGPoint,
                state: @escaping () -> GestureRecognizer.State)
  {
    guard objc_getAssociatedObject(self, &GestureRecognizer.subclassKey) == nil else {
      // already subclassed, just update the properties
      objc_setAssociatedObject(self, &GestureRecognizer.locationInViewBlockKey, locationInView, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      objc_setAssociatedObject(self, &GestureRecognizer.stateBlockKey, state, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      return
    }

    guard let originalClass = object_getClass(self) else {
      return
    }
    let originalClassName = String(cString: class_getName(originalClass))
    let subclassName = originalClassName.appending("_Subclass")

    let subclass: AnyClass
    if let existingSubclass = NSClassFromString(subclassName) {
      subclass = existingSubclass
    } else {
      guard let subclassNameUtf8 = (subclassName as NSString).utf8String,
            let newSubclass = objc_allocateClassPair(originalClass, subclassNameUtf8, 0)
      else {
        return
      }

      // override `location(in:)`
      do {
        let selector = #selector(GestureRecognizer.location(in:))
        guard let method = class_getInstanceMethod(originalClass, selector) else {
          return
        }

        let originalMethodIMP = method_getImplementation(method) // can also use: class_getMethodImplementation(originalClass, selector)
        typealias OriginalMethodIMP = @convention(c) (AnyObject, Selector, View?) -> CGPoint
        let originalMethod = unsafeBitCast(originalMethodIMP, to: OriginalMethodIMP.self)

        let block: @convention(block) (AnyObject, View?) -> CGPoint = { object, parameter1 in
          if let locationInViewBlock = objc_getAssociatedObject(object, &GestureRecognizer.locationInViewBlockKey) as? ((View?) -> CGPoint) {
            return locationInViewBlock(parameter1)
          }
          return originalMethod(object, selector, parameter1)
        }
        class_addMethod(newSubclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      }

      // override `state`
      do {
        let selector = #selector(getter: GestureRecognizer.state)
        guard let method = class_getInstanceMethod(originalClass, selector) else {
          return
        }

        let originalMethodIMP = method_getImplementation(method)
        typealias OriginalMethodIMP = @convention(c) (AnyObject, Selector) -> GestureRecognizer.State
        let originalMethod = unsafeBitCast(originalMethodIMP, to: OriginalMethodIMP.self)

        let block: @convention(block) (AnyObject) -> GestureRecognizer.State = { object in
          if let stateBlock = objc_getAssociatedObject(object, &GestureRecognizer.stateBlockKey) as? (() -> GestureRecognizer.State) {
            return stateBlock()
          }
          return originalMethod(object, selector)
        }
        class_addMethod(newSubclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      }

      objc_registerClassPair(newSubclass)
      subclass = newSubclass
    }

    // set the instance's class to the subclass
    object_setClass(self, subclass)

    objc_setAssociatedObject(self, &GestureRecognizer.locationInViewBlockKey, locationInView, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    objc_setAssociatedObject(self, &GestureRecognizer.stateBlockKey, state, .OBJC_ASSOCIATION_COPY_NONATOMIC)

    // mark this instance as subclassed
    objc_setAssociatedObject(self, &GestureRecognizer.subclassKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }
}
