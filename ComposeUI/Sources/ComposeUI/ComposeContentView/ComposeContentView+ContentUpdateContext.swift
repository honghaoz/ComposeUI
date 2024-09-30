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
      case refresh

      /// View bounds changed.
      case boundsChange
    }

    let updateType: ContentUpdateType

    var isRendering: Bool = false

    init(updateType: ContentUpdateType) {
      self.updateType = updateType
    }
  }
}
