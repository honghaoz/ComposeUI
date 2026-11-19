//
//  record-screen.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/18/26.
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

// Records a rectangle of the main screen with ScreenCaptureKit, losslessly and in sRGB, for the README media.
//
// usage: record-screen <x> <y> <width> <height> <seconds> <out-dir> <cursor 0|1>
//
// The rectangle is in points from the top-left corner of the main screen, and the frames are captured at 2x. It writes
// `frames.raw`, the BGRA frames tightly packed, and `times.txt`, the presentation time of each frame. ScreenCaptureKit
// delivers a frame only when the screen changes, so the times also show when the content is still.

import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

let arguments = CommandLine.arguments
guard arguments.count == 8,
      let x = Double(arguments[1]), let y = Double(arguments[2]),
      let width = Double(arguments[3]), let height = Double(arguments[4]),
      let seconds = Double(arguments[5])
else {
  FileHandle.standardError.write(Data("usage: record-screen <x> <y> <width> <height> <seconds> <out-dir> <cursor 0|1>\n".utf8))
  exit(2)
}

let rect = CGRect(x: x, y: y, width: width, height: height)
let outDirectory = URL(fileURLWithPath: arguments[6])
let showsCursor = arguments[7] == "1"
let pixelWidth = Int(rect.width * 2)
let pixelHeight = Int(rect.height * 2)

try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
let framesURL = outDirectory.appendingPathComponent("frames.raw")
FileManager.default.createFile(atPath: framesURL.path, contents: nil)
let framesFile = try FileHandle(forWritingTo: framesURL)
var times: [Double] = []

final class FrameWriter: NSObject, SCStreamOutput {

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    // an idle frame repeats the last one, so only the complete frames are written
    guard type == .screen,
          let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
          let rawStatus = attachments.first?[.status] as? Int,
          SCFrameStatus(rawValue: rawStatus) == .complete,
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else {
      return
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer {
      CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
    guard CVPixelBufferGetWidth(pixelBuffer) == pixelWidth,
          CVPixelBufferGetHeight(pixelBuffer) == pixelHeight,
          let base = CVPixelBufferGetBaseAddress(pixelBuffer)
    else {
      return
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    var data = Data(capacity: pixelWidth * pixelHeight * 4)
    for row in 0 ..< pixelHeight {
      data.append(base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self), count: pixelWidth * 4)
    }
    framesFile.write(data)
    times.append(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
  }
}

let writer = FrameWriter()
let queue = DispatchQueue(label: "io.chouti.composeui.readmeMedia.recordScreen")

Task {
  do {
    let content = try await SCShareableContent.current
    guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
      throw CocoaError(.featureUnsupported)
    }
    let configuration = SCStreamConfiguration()
    configuration.sourceRect = rect
    configuration.width = pixelWidth
    configuration.height = pixelHeight
    configuration.scalesToFit = false
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
    configuration.pixelFormat = kCVPixelFormatType_32BGRA
    // the frames are converted to sRGB, so that the colors match the app's colors instead of the display's
    configuration.colorSpaceName = CGColorSpace.sRGB
    configuration.showsCursor = showsCursor
    if #available(macOS 15.0, *) {
      configuration.showMouseClicks = showsCursor
    }
    configuration.queueDepth = 8

    let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration, delegate: nil)
    try stream.addStreamOutput(writer, type: .screen, sampleHandlerQueue: queue)
    try await stream.startCapture()
    try await Task.sleep(nanoseconds: UInt64(seconds * 1e9))
    try await stream.stopCapture()

    queue.sync {
      try? framesFile.close()
      try? times.map { String(format: "%.6f", $0) }.joined(separator: "\n")
        .write(to: outDirectory.appendingPathComponent("times.txt"), atomically: true, encoding: .utf8)
      print("recorded \(times.count) frames")
    }
    exit(0)
  } catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
  }
}

RunLoop.main.run()
