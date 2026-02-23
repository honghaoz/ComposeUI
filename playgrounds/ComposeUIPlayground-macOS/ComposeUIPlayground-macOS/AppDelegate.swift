//
//  AppDelegate.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/27/24.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  private var window: NSWindow?

  func applicationDidFinishLaunching(_ aNotification: Notification) {

    // create the window
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )

    window.contentViewController = ViewController()

    // configure window
    window.center()
    window.setFrameAutosaveName("main-window")
    window.title = "ComposéUI"

    // make window visible
    window.makeKeyAndOrderFront(nil)

    self.window = window
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
