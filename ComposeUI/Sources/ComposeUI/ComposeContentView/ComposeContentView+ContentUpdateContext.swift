//
//  ContentUpdateContext.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import Foundation

extension ComposeContentView {

  struct ContentUpdateContext {

    enum ContentUpdateType {

      /// Explicit refresh.
      case refresh(isAnimated: Bool)

      /// View bounds changed.
      case boundsChange
    }

    let updateType: ContentUpdateType

    var isRendering: Bool = false

    var isAnimated: Bool {
      switch updateType {
      case .refresh(let isAnimated):
        return isAnimated
      case .boundsChange:
        return false
      }
    }

    init(updateType: ContentUpdateType) {
      self.updateType = updateType
    }
  }
}
