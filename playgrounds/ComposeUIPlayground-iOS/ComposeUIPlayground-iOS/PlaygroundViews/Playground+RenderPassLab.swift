//
//  Playground+RenderPassLab.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/17/26.
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

  /// A lab for the render pass behaviors.
  ///
  /// A container `ComposeView` renders a content preset, including nested views. You resize the container directly
  /// (drag its handle, or let it follow the window on macOS), refresh it or a nested view, and change their animation
  /// behaviors, while a log shows each render pass as it happens and whether reused renderables animated. Guided
  /// checks set the lab up, perform an action, and verify the outcome, so each behavior has a one-tap proof.
  ///
  /// The lab lays the container out itself, instead of through a `ComposeView`, so a resize is a bounds change of the
  /// container, like a window resize, and not a refresh of a parent that happens to resize it.
  final class RenderPassLab: BaseView {

    let model = Model()

    /// The view whose render passes the lab demonstrates.
    private(set) lazy var container = ComposeView { [model] in
      model.buildContent()
    }

    private lazy var controls = ComposeView { [weak self] in
      self?.controlsContent ?? Empty()
    }

    private lazy var status = ComposeView { [weak self] in
      self?.statusContent ?? Empty()
    }

    /// A view behind the container drawing its outline, so the container's size is visible.
    private let containerOutline = BaseView()

    /// The handle that resizes the container: a grabber above a bottom panel on iOS, a corner knob on macOS.
    private let resizeHandle = BaseView()

    /// The container's height on iOS, or its size on macOS while it does not follow the window.
    private var containerSize = Constants.defaultContainerSize

    /// Whether the container fills the area below the controls, so resizing the window resizes it. macOS only.
    private var followsWindow = !Constants.isPanel

    /// The area the container may occupy, from the last layout.
    private var containerArea: CGRect = .zero

    private var dragStartSize: CGSize = .zero

    /// The last render pass of each view, by the view's name.
    private var lastPasses: [String: String] = [:]

    /// The names of the views in the order their render passes completed during the running check, for checking which
    /// pass ran when. Recorded only while a check runs, so scrolling for hours does not grow it.
    private var passSequence: [String] = []

    private var logLines: [LogLine] = []

    private var selectedCheck: Check = .resizeKeepsContent

    /// The check in flight, from "Run check" until its result is in.
    private var runningCheck: Check?

    /// The result of the last check run, shown in the status.
    private var checkResult: String?

    /// The scenario a render handler performs on its next call, armed by a check.
    private var armedScenario: Scenario?

    private let timeFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "mm:ss.SSS"
      return formatter
    }()

    override init(frame: CGRect) {
      super.init(frame: frame)

      #if canImport(AppKit)
      wantsLayer = true
      #endif

      addSubview(controls)
      addSubview(status)
      addSubview(containerOutline)
      addSubview(container)
      addSubview(resizeHandle)

      status.clippingBehavior = .always

      let outlineLayer = Self.layer(of: containerOutline)
      outlineLayer.borderColor = Colors.blueGray.cgColor
      outlineLayer.borderWidth = Constants.outlineWidth

      let handleLayer = Self.layer(of: resizeHandle)
      handleLayer.backgroundColor = Colors.darkBlueGray.cgColor
      handleLayer.cornerRadius = Constants.resizeHandleSize.height / 2
      resizeHandle.addGestureRecognizer(PanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
      #if canImport(AppKit)
      resizeHandle.setAccessibilityElement(true)
      resizeHandle.setAccessibilityRole(.handle)
      resizeHandle.setAccessibilityLabel("Resize handle")
      #else
      resizeHandle.isAccessibilityElement = true
      resizeHandle.accessibilityLabel = "Resize handle"
      #endif

      container.animationBehavior = model.containerBehavior.animationBehavior
      container.onWillRender { [weak self] _, _ in
        self?.containerWillRender()
      }
      container.onDidRender { [weak self] _, context in
        self?.recordPass(of: Owner.container, context.renderType)
      }

      model.onNestedViewInserted = { [weak self] view in
        self?.wireNestedView(view, name: Owner.nested)
      }
      wireNestedView(model.hostedComposeView, name: Owner.hosted)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
    }

    // MARK: - Layout

    override func layoutSubviews() {
      super.layoutSubviews()

      let padding = Constants.padding
      let width = bounds.width - padding * 2
      var y = padding

      controls.frame = CGRect(x: padding, y: y, width: width, height: Constants.controlsHeight)
      y += Constants.controlsHeight + Constants.sectionSpacing

      status.frame = CGRect(x: padding, y: y, width: width, height: Constants.statusHeight)
      y += Constants.statusHeight + Constants.sectionSpacing

      containerArea = CGRect(x: padding, y: y, width: width, height: max(bounds.height - y - padding, 0))
      applyContainerFrame()
    }

    /// Sets the container's frame from its size or the window. A changed frame is a bounds change of the container.
    ///
    /// The container keeps its minimum size while the area allows it, and shrinks with the area below that (a landscape
    /// phone, a small window), so it never draws over the controls and status.
    private func applyContainerFrame() {
      let handleSize = Constants.resizeHandleSize
      let frame: CGRect
      if Constants.isPanel {
        // a full-width panel at the bottom, leaving room above it for the grabber
        let maxHeight = max(containerArea.height - handleSize.height - Constants.grabberSpacing, 0)
        let height = Self.clamp(containerSize.height, max: maxHeight)
        frame = CGRect(x: containerArea.minX, y: containerArea.maxY - height, width: containerArea.width, height: height)
        resizeHandle.frame = CGRect(x: frame.midX - handleSize.width / 2, y: frame.minY - handleSize.height - Constants.grabberSpacing, width: handleSize.width, height: handleSize.height)
      } else if followsWindow {
        frame = containerArea
      } else {
        let size = CGSize(
          width: Self.clamp(containerSize.width, max: containerArea.width),
          height: Self.clamp(containerSize.height, max: containerArea.height)
        )
        frame = CGRect(origin: containerArea.origin, size: size)
        resizeHandle.frame = CGRect(x: frame.maxX - handleSize.width / 2, y: frame.maxY - handleSize.height / 2, width: handleSize.width, height: handleSize.height)
      }

      container.frame = frame
      containerOutline.frame = frame.insetBy(dx: -Constants.outlineWidth, dy: -Constants.outlineWidth)
      resizeHandle.isHidden = !Constants.isPanel && followsWindow

      status.setNeedsRefresh(animated: false)
    }

    /// Resizes the container by a step, as a window resize would: taller on iOS, wider on macOS. Shrinks when the
    /// container is already as large as its area allows, so the action always changes the container's bounds.
    private func resizeContainer() {
      let size = container.frame.size
      followsWindow = false
      containerSize = Self.size(size, resizedBy: Constants.resizeStep)
      applyContainerFrame()
      if container.frame.size == size {
        containerSize = Self.size(size, resizedBy: -Constants.resizeStep)
        applyContainerFrame()
      }
      Self.layoutNow(container)
    }

    private static func size(_ size: CGSize, resizedBy step: CGFloat) -> CGSize {
      Constants.isPanel ? CGSize(width: size.width, height: size.height + step) : CGSize(width: size.width + step, height: size.height)
    }

    /// Clamps a container dimension to the minimum size and the available size, the available size winning when it
    /// is the smaller one.
    private static func clamp(_ value: CGFloat, max available: CGFloat) -> CGFloat {
      min(max(value, Constants.minContainerSize), max(available, 0))
    }

    @objc private func handlePan(_ gesture: PanGestureRecognizer) {
      switch gesture.state {
      case .began:
        dragStartSize = container.frame.size
      case .changed:
        let translation = gesture.translation(in: self)
        if Constants.isPanel {
          // the grabber is above the panel, so dragging up grows it
          containerSize = CGSize(width: dragStartSize.width, height: dragStartSize.height - translation.y)
        } else {
          containerSize = CGSize(width: dragStartSize.width + translation.x, height: dragStartSize.height + translation.y)
        }
        applyContainerFrame()
      case .ended,
           .cancelled:
        containerSize = container.frame.size
      default:
        break
      }
    }

    // MARK: - Controls

    @ComposeContentBuilder
    private var controlsContent: ComposeContent {
      VStack(spacing: Constants.controlSpacing) {
        HStack(spacing: Constants.controlSpacing) {
          button("Content: \(model.preset.title)") { [weak self] in
            guard let self else {
              return
            }
            self.model.preset = self.model.preset.next
            self.log("tap: content -> \(self.model.preset.title), container.refresh (instant)")
            self.container.refresh(animated: false)
          }
          button("Mutate data") { [weak self] in
            self?.model.mutate()
            self?.log("tap: data mutated, refresh to apply")
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Container: \(model.containerBehavior.title)") { [weak self] in
            guard let self else {
              return
            }
            self.setContainerBehavior(self.model.containerBehavior.next)
            self.log("tap: container behavior -> \(self.model.containerBehavior.title)")
          }
          button("Refresh (anim)") { [weak self] in
            self?.log("tap: container.refresh (animated)")
            self?.container.refresh(animated: true)
          }
          button("Refresh (now)") { [weak self] in
            self?.log("tap: container.refresh (instant)")
            self?.container.refresh(animated: false)
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Nested: \(model.nestedBehavior.title)") { [weak self] in
            guard let self else {
              return
            }
            self.setNestedBehavior(self.model.nestedBehavior.next)
            self.log("tap: nested behavior -> \(self.model.nestedBehavior.title)")
          }
          button("Refresh (anim)") { [weak self] in
            self?.refreshNestedView(animated: true)
          }
          button("Refresh (now)") { [weak self] in
            self?.refreshNestedView(animated: false)
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)

        HStack(spacing: Constants.controlSpacing) {
          button("Check: \(selectedCheck.title)") { [weak self] in
            guard let self, self.runningCheck == nil else {
              return
            }
            self.selectedCheck = self.selectedCheck.next
            self.checkResult = nil
            self.status.setNeedsRefresh(animated: false)
          }
          button("Run check") { [weak self] in
            self?.runCheck()
          }
          if !Constants.isPanel {
            button(followsWindow ? "Follow window: on" : "Follow window: off") { [weak self] in
              guard let self else {
                return
              }
              self.followsWindow.toggle()
              self.log("tap: follow window -> \(self.followsWindow)")
              self.applyContainerFrame()
            }
          }
        }
        .frame(width: .flexible, height: Constants.controlHeight)
      }
    }

    private func button(_ title: String, onTap: @escaping () -> Void) -> ComposeNode {
      Playground.button(title: title, fontSize: Constants.controlFontSize) { [weak self] in
        onTap()
        self?.controls.refresh(animated: false)
      }
    }

    private func setContainerBehavior(_ behavior: Behavior) {
      model.containerBehavior = behavior
      container.animationBehavior = behavior.animationBehavior
    }

    private func setNestedBehavior(_ behavior: Behavior) {
      model.nestedBehavior = behavior
      model.nestedComposeView?.animationBehavior = behavior.animationBehavior
      model.hostedComposeView.animationBehavior = behavior.animationBehavior
    }

    private func refreshNestedView(animated: Bool) {
      guard let nestedView = model.currentNestedView, let owner = model.currentNestedOwner else {
        log("tap: no nested view in the \(model.preset.title) preset")
        return
      }
      log("tap: \(owner).refresh (\(animated ? "animated" : "instant"))")
      nestedView.refresh(animated: animated)
    }

    // MARK: - Scenarios

    /// An action a render handler performs during a pass, to show how a request made during a pass runs.
    private enum Scenario {

      /// The nested view's did-render handler refreshes the container.
      case parentRefreshFromNested

      /// The nested view's did-render handler resizes the container.
      case parentResizeFromNested

      /// The container's will-render handler refreshes the nested view, before the container has its decision.
      case nestedRefreshFromParentWillRender
    }

    /// Arms the scenario and starts the pass whose handler performs it.
    private func run(_ scenario: Scenario) {
      guard let nestedView = model.currentNestedView, let owner = model.currentNestedOwner else {
        return
      }
      armedScenario = scenario
      switch scenario {
      case .parentRefreshFromNested,
           .parentResizeFromNested:
        log("check: \(owner).refresh (instant)")
        nestedView.refresh(animated: false)
      case .nestedRefreshFromParentWillRender:
        log("check: container.refresh (instant)")
        container.refresh(animated: false)
      }
    }

    private func containerWillRender() {
      guard armedScenario == .nestedRefreshFromParentWillRender, let nestedView = model.currentNestedView, let owner = model.currentNestedOwner else {
        return
      }
      armedScenario = nil
      log("container willRender: \(owner).refresh (animated)")
      nestedView.refresh(animated: true)
    }

    private func nestedDidRender(_ owner: String) {
      switch armedScenario {
      case .parentRefreshFromNested:
        armedScenario = nil
        log("\(owner) didRender: container.refresh (instant)")
        container.refresh(animated: false)
      case .parentResizeFromNested:
        armedScenario = nil
        log("\(owner) didRender: container resizes by \(Int(Constants.resizeStep)), layout")
        resizeContainer()
      case .nestedRefreshFromParentWillRender,
           .none:
        break
      }
    }

    // MARK: - Checks

    /// A guided check: the lab sets itself up, performs the action, and verifies the outcome from the recorded passes.
    private enum Check: CaseIterable {

      case resizeKeepsContent
      case refreshAppliesData
      case resizeRowsSnap
      case dynamicRowsAnimate
      case containerCapsNested
      case nestedAloneKeepsContent
      case hostedAloneAnimates
      case hostedResizesInPass
      case requestInPassWaits
      case layoutInPassWaits
      case earlyNestedRefreshWaits

      var title: String {
        switch self {
        case .resizeKeepsContent:
          return "resize keeps content"
        case .refreshAppliesData:
          return "refresh applies data"
        case .resizeRowsSnap:
          return "resize: rows snap"
        case .dynamicRowsAnimate:
          return "dynamic: rows animate"
        case .containerCapsNested:
          return "container caps nested"
        case .nestedAloneKeepsContent:
          return "nested alone keeps rows"
        case .hostedAloneAnimates:
          return "hosted alone animates"
        case .hostedResizesInPass:
          return "hosted resizes in pass"
        case .requestInPassWaits:
          return "request in pass waits"
        case .layoutInPassWaits:
          return "layout in pass waits"
        case .earlyNestedRefreshWaits:
          return "early nested refresh waits"
        }
      }

      /// The preset and behaviors the lab renders before the action. Kept short enough for one status line.
      var setup: String {
        switch self {
        case .resizeKeepsContent,
             .refreshAppliesData,
             .resizeRowsSnap:
          return "color rows, container default"
        case .dynamicRowsAnimate:
          return "color rows, container dynamic"
        case .containerCapsNested,
             .nestedAloneKeepsContent:
          return "nested view, container disabled, nested dynamic"
        case .hostedAloneAnimates:
          return "hosted view, container disabled, hosted dynamic"
        case .hostedResizesInPass,
             .earlyNestedRefreshWaits:
          return "hosted view, both default"
        case .requestInPassWaits,
             .layoutInPassWaits:
          return "nested view, both default"
        }
      }

      /// What "Run check" does after the setup rendered.
      var action: String {
        switch self {
        case .resizeKeepsContent:
          return "mutate data, resize the container by \(Int(Constants.resizeStep))"
        case .refreshAppliesData:
          return "mutate data, container.refresh (instant)"
        case .resizeRowsSnap,
             .dynamicRowsAnimate,
             .hostedResizesInPass:
          return "resize the container by \(Int(Constants.resizeStep))"
        case .containerCapsNested:
          return "mutate data, container.refresh (animated)"
        case .nestedAloneKeepsContent:
          return "mutate data, nested.refresh (animated)"
        case .hostedAloneAnimates:
          return "mutate data, hosted.refresh (animated)"
        case .requestInPassWaits:
          return "nested.refresh, didRender: container.refresh"
        case .layoutInPassWaits:
          return "nested.refresh, didRender: container resizes"
        case .earlyNestedRefreshWaits:
          return "container.refresh, willRender: hosted.refresh"
        }
      }

      /// What the check verifies.
      var expectation: String {
        switch self {
        case .resizeKeepsContent:
          return "no build, rows resize (instant), color unchanged"
        case .refreshAppliesData:
          return "one build, rows refresh, color changed"
        case .resizeRowsSnap:
          return "rows resize (instant)"
        case .dynamicRowsAnimate:
          return "rows resize (animated)"
        case .containerCapsNested:
          return "container builds rows, nested refresh (instant)"
        case .nestedAloneKeepsContent:
          return "no rows build, re-renders the container's rows"
        case .hostedAloneAnimates:
          return "hosted builds rows, rows refresh (animated)"
        case .hostedResizesInPass:
          return "hosted resize inside the container's pass"
        case .requestInPassWaits:
          return "container pass after the nested pass ended"
        case .layoutInPassWaits:
          return "container resize after the nested pass ended"
        case .earlyNestedRefreshWaits:
          return "hosted refresh (animated) after the container's"
        }
      }

      /// The next check in the cycle.
      var next: Check {
        let checks = Self.allCases
        // swiftlint:disable:next force_unwrapping
        let index = checks.firstIndex(of: self)!
        return checks[(index + 1) % checks.count]
      }
    }

    /// The observable state a check compares before and after its action.
    private struct Snapshot {

      let passSequence: [String]
      let buildCount: Int
      let rowBuilds: [String: Int]
      let lastPasses: [String: String]
      let rowUpdates: [String: RowUpdate]

      /// The names of the views whose passes completed after the earlier snapshot, in order.
      func passes(since earlier: Snapshot) -> [String] {
        Array(passSequence.dropFirst(earlier.passSequence.count))
      }

      /// How many times the rows of a view were built since the earlier snapshot.
      func rowBuilds(of owner: String, since earlier: Snapshot) -> Int {
        (rowBuilds[owner] ?? 0) - (earlier.rowBuilds[owner] ?? 0)
      }

      /// Whether the first row of a view shows a different color than in the earlier snapshot.
      func rowColorChanged(of owner: String, since earlier: Snapshot) -> Bool {
        rowUpdates[owner]?.color != earlier.rowUpdates[owner]?.color
      }
    }

    private func snapshot() -> Snapshot {
      Snapshot(
        passSequence: passSequence,
        buildCount: model.buildCount,
        rowBuilds: model.rowBuilds,
        lastPasses: lastPasses,
        rowUpdates: model.rowUpdates
      )
    }

    /// Runs the selected check: configure, let the setup settle, act, then verify once deferred passes had a turn.
    ///
    /// A run spans a few run loop turns. A second run in that window would share the recorded passes and the armed
    /// scenario, so it is ignored.
    private func runCheck() {
      guard runningCheck == nil else {
        return
      }
      let check = selectedCheck
      runningCheck = check
      checkResult = "running"
      passSequence = []
      log("check: \(check.title)")
      configure(for: check)
      controls.refresh(animated: false)

      Self.afterRunLoopTurn { [weak self] in
        guard let self else {
          return
        }
        let before = self.snapshot()
        self.perform(check)
        let afterAction = self.snapshot()
        self.controls.refresh(animated: false)
        // deferred passes run on the next run loop iteration, and may schedule one more, so wait two turns
        Self.afterRunLoopTurn {
          Self.afterRunLoopTurn { [weak self] in
            guard let self else {
              return
            }
            let settled = self.snapshot()
            let result = self.verify(check, before: before, afterAction: afterAction, settled: settled)
            self.runningCheck = nil
            self.checkResult = result
            self.log("check: \(result)")
          }
        }
      }
    }

    private func mutateData() {
      model.mutate()
      log("check: data mutated")
    }

    private func configure(for check: Check) {
      // a fresh render of the preset, so the action starts from a settled state
      switch check {
      case .resizeKeepsContent,
           .refreshAppliesData,
           .resizeRowsSnap:
        model.preset = .colorRows
        setContainerBehavior(.default)
      case .dynamicRowsAnimate:
        model.preset = .colorRows
        setContainerBehavior(.dynamic)
      case .containerCapsNested,
           .nestedAloneKeepsContent:
        model.preset = .nestedComposeView
        setContainerBehavior(.disabled)
        setNestedBehavior(.dynamic)
      case .hostedAloneAnimates:
        model.preset = .hostedComposeView
        setContainerBehavior(.disabled)
        setNestedBehavior(.dynamic)
      case .hostedResizesInPass,
           .earlyNestedRefreshWaits:
        model.preset = .hostedComposeView
        setContainerBehavior(.default)
        setNestedBehavior(.default)
      case .requestInPassWaits,
           .layoutInPassWaits:
        model.preset = .nestedComposeView
        setContainerBehavior(.default)
        setNestedBehavior(.default)
      }
      container.refresh(animated: false)
    }

    private func perform(_ check: Check) {
      switch check {
      case .resizeKeepsContent:
        mutateData()
        log("check: container resizes by \(Int(Constants.resizeStep))")
        resizeContainer()
      case .resizeRowsSnap,
           .dynamicRowsAnimate,
           .hostedResizesInPass:
        log("check: container resizes by \(Int(Constants.resizeStep))")
        resizeContainer()
      case .refreshAppliesData:
        mutateData()
        log("check: container.refresh (instant)")
        container.refresh(animated: false)
      case .containerCapsNested:
        mutateData()
        log("check: container.refresh (animated)")
        container.refresh(animated: true)
      case .nestedAloneKeepsContent,
           .hostedAloneAnimates:
        mutateData()
        log("check: \(model.currentNestedOwner ?? "nested").refresh (animated)")
        model.currentNestedView?.refresh(animated: true)
      case .requestInPassWaits:
        run(.parentRefreshFromNested)
      case .layoutInPassWaits:
        run(.parentResizeFromNested)
      case .earlyNestedRefreshWaits:
        run(.nestedRefreshFromParentWillRender)
      }
    }

    /// Verifies the check from the snapshots taken before the action, right after its synchronous part, and after
    /// deferred passes had their turn. The result names what was observed, so a failure shows what differed.
    private func verify(_ check: Check, before: Snapshot, afterAction: Snapshot, settled: Snapshot) -> String {
      let containerRows = settled.rowUpdates[Owner.container]?.description ?? "-"
      let nestedRows = settled.rowUpdates[Owner.nested]?.description ?? "-"
      let hostedRows = settled.rowUpdates[Owner.hosted]?.description ?? "-"
      let builds = settled.buildCount - before.buildCount
      // the passes the action ran itself, and the ones that ran on the following run loop iterations
      let during = afterAction.passes(since: before)
      let after = settled.passes(since: afterAction)
      let order = "during: \(Self.describe(during)), after: \(Self.describe(after))"
      // the rendered output: whether the first row's layer shows a different color than before the action
      let containerColorChanged = settled.rowColorChanged(of: Owner.container, since: before)
      let nestedColorChanged = settled.rowColorChanged(of: Owner.nested, since: before)
      let hostedColorChanged = settled.rowColorChanged(of: Owner.hosted, since: before)

      switch check {
      case .resizeKeepsContent:
        return Self.result(builds == 0 && containerRows == "resize (instant)" && !containerColorChanged, "builds \(builds), rows \(containerRows), color \(Self.describe(changed: containerColorChanged))")
      case .refreshAppliesData:
        return Self.result(builds == 1 && settled.rowUpdates[Owner.container]?.kind == "refresh" && containerColorChanged, "builds \(builds), rows \(containerRows), color \(Self.describe(changed: containerColorChanged))")
      case .resizeRowsSnap:
        return Self.result(containerRows == "resize (instant)", "rows \(containerRows)")
      case .dynamicRowsAnimate:
        return Self.result(containerRows == "resize (animated)", "rows \(containerRows)")
      case .containerCapsNested:
        let pass = settled.lastPasses[Owner.nested] ?? "-"
        let nestedBuilds = settled.rowBuilds(of: Owner.nested, since: before)
        return Self.result(nestedBuilds == 1 && pass == "refresh (instant)" && nestedRows == "refresh (instant)" && nestedColorChanged, "nested rows built \(nestedBuilds), nested pass \(pass), rows \(nestedRows), color \(Self.describe(changed: nestedColorChanged))")
      case .nestedAloneKeepsContent:
        // the container built the rows the nested view renders, so its own refresh re-renders them: the pass is
        // animated as its behavior asks, but no row changes, so nothing moves
        let nestedBuilds = settled.rowBuilds(of: Owner.nested, since: before)
        return Self.result(nestedBuilds == 0 && nestedRows == "refresh (animated)" && !nestedColorChanged, "nested rows built \(nestedBuilds), rows \(nestedRows), color \(Self.describe(changed: nestedColorChanged))")
      case .hostedAloneAnimates:
        let hostedBuilds = settled.rowBuilds(of: Owner.hosted, since: before)
        return Self.result(hostedBuilds == 1 && hostedRows == "refresh (animated)" && hostedColorChanged, "hosted rows built \(hostedBuilds), rows \(hostedRows), color \(Self.describe(changed: hostedColorChanged))")
      case .hostedResizesInPass:
        // the hosted pass completes before the container's, so it ran inside the container's pass
        let pass = afterAction.lastPasses[Owner.hosted] ?? "-"
        return Self.result(during == [Owner.hosted, Owner.container] && pass.hasPrefix("resize") && hostedRows == "resize (instant)", "\(order), hosted \(pass), rows \(hostedRows)")
      case .requestInPassWaits:
        return Self.result(during == [Owner.nested] && after.last == Owner.container, order)
      case .layoutInPassWaits:
        let pass = settled.lastPasses[Owner.container] ?? "-"
        return Self.result(during == [Owner.nested] && after.last == Owner.container && pass.hasPrefix("resize"), "\(order), container \(pass)")
      case .earlyNestedRefreshWaits:
        return Self.result(during == [Owner.container] && after == [Owner.hosted] && hostedRows == "refresh (animated)", "\(order), rows \(hostedRows)")
      }
    }

    private static func result(_ passed: Bool, _ observed: String) -> String {
      "\(passed ? "PASS" : "FAIL"): \(observed)"
    }

    private static func describe(changed: Bool) -> String {
      changed ? "changed" : "unchanged"
    }

    private static func describe(_ passes: [String]) -> String {
      passes.isEmpty ? "none" : passes.joined(separator: " > ")
    }

    // MARK: - Nested Views

    private func wireNestedView(_ view: ComposeView, name: String) {
      view.animationBehavior = model.nestedBehavior.animationBehavior
      view.onDidRender { [weak self] _, context in
        self?.recordPass(of: name, context.renderType)
        self?.nestedDidRender(name)
      }
    }

    // MARK: - Status

    /// The state lines above a divider, the log below it in a dimmer color. The log fills the rest of the panel from
    /// the bottom up, so when wrapped lines make it taller than the space, the oldest lines are the ones that do not
    /// show. It sits in its own view, which clips them at the divider instead of letting them draw over the state.
    private var statusContent: ComposeContent {
      VStack(spacing: Constants.statusSpacing) {
        statusLabel(statusText, color: Self.labelColor)
        ColorNode(Colors.blueGray)
          .frame(width: .flexible, height: Constants.outlineWidth)
        ComposeViewNode {
          statusLabel(logText, color: Self.secondaryLabelColor)
            .frame(width: .flexible, height: .flexible, alignment: .bottomLeft)
        }
        .flexibleSize()
        .willInsert { renderable, _ in
          // the content is never larger than the view, so the default clipping would leave the overflow visible
          (renderable.view as? ComposeView)?.clippingBehavior = .always
        }
      }
    }

    private var statusText: String {
      let sizing = Constants.isPanel ? "bottom panel" : (followsWindow ? "follows window" : "fixed")
      var lines = [
        // a pass is described by its request, so a capped refresh reads "refresh (animated)" while its rows read "(instant)"
        "pass: what was requested, rows: what the first row got",
        "container \(Self.describe(container.frame.size)) \(sizing)",
        "  pass  \(lastPasses[Owner.container] ?? "-")",
        "  rows  \(model.rowUpdates[Owner.container]?.description ?? "-")",
      ]
      if let nestedOwner = model.currentNestedOwner, let note = model.currentNestedNote {
        lines += [
          "\(nestedOwner) (\(model.preset.title), \(note))",
          "  pass  \(lastPasses[nestedOwner] ?? "-")",
          "  rows  \(model.rowUpdates[nestedOwner]?.description ?? "-")",
        ]
      } else {
        lines.append("nested  none in the \(model.preset.title) preset")
      }
      lines += [
        "check \(selectedCheck.title)",
        "  setup   \(selectedCheck.setup)",
        "  action  \(selectedCheck.action)",
        "  expect  \(selectedCheck.expectation)",
        "  result  \(checkResult ?? "-")",
      ]
      return lines.joined(separator: "\n")
    }

    private var logText: String {
      (["log"] + logLines.map { "\($0.time) \($0.message)" }).joined(separator: "\n")
    }

    private func statusLabel(_ text: String, color: Color) -> ComposeNode {
      Label(text)
        .font(.monospacedSystemFont(ofSize: Constants.statusFontSize, weight: .regular))
        .textColor(color)
        .numberOfLines(0)
        .lineBreakMode(.byTruncatingTail)
        .textAlignment(.left)
        .selectable(false)
        .fixedSize(width: false, height: true)
    }

    private func recordPass(of name: String, _ renderType: ComposeView.RenderType) {
      let description = Self.describe(renderType)
      lastPasses[name] = description
      if runningCheck != nil {
        passSequence.append(name)
      }
      log("\(name) \(description)", coalescing: Self.isScroll(renderType) ? "\(name) scroll" : nil)
    }

    /// A log line with its time, kept apart so consecutive scroll passes of one view can replace each other.
    private struct LogLine {

      let time: String
      let message: String

      /// A key under which the next line replaces this one instead of following it, or nil.
      let coalescingKey: String?
    }

    /// Appends a timestamped line to the log and schedules a status update, which never interrupts a pass in progress.
    ///
    /// - Parameters:
    ///   - message: The message.
    ///   - coalescingKey: If the last line has the same key, the new line replaces it, so a burst of scroll passes
    ///     takes one line instead of pushing everything else out of the log.
    private func log(_ message: String, coalescing coalescingKey: String? = nil) {
      let line = LogLine(time: timeFormatter.string(from: Date()), message: message, coalescingKey: coalescingKey)
      if let coalescingKey, logLines.last?.coalescingKey == coalescingKey {
        logLines[logLines.count - 1] = line
      } else {
        logLines.append(line)
      }
      if logLines.count > Constants.logLineCount {
        logLines.removeFirst(logLines.count - Constants.logLineCount)
      }
      status.setNeedsRefresh(animated: false)
    }

    // MARK: - Helpers

    private static func describe(_ renderType: ComposeView.RenderType) -> String {
      switch renderType {
      case .refresh(let isAnimated):
        return isAnimated ? "refresh (animated)" : "refresh (instant)"
      case .boundsChange(let previousBounds, let bounds):
        guard let previousBounds else {
          return "first layout \(describe(bounds.size))"
        }
        var parts: [String] = []
        if previousBounds.size != bounds.size {
          parts.append("resize \(describe(previousBounds.size)) -> \(describe(bounds.size))")
        }
        if previousBounds.origin != bounds.origin {
          parts.append("scroll \(describe(previousBounds.origin)) -> \(describe(bounds.origin))")
        }
        return parts.isEmpty ? "bounds change (unchanged)" : parts.joined(separator: ", ")
      }
    }

    /// Whether the pass only moved the viewport, which happens on every scroll tick.
    private static func isScroll(_ renderType: ComposeView.RenderType) -> Bool {
      guard case .boundsChange(let previousBounds?, let bounds) = renderType else {
        return false
      }
      return previousBounds.size == bounds.size && previousBounds.origin != bounds.origin
    }

    private static func describe(_ size: CGSize) -> String {
      "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private static func describe(_ point: CGPoint) -> String {
      "\(Int(point.x.rounded())),\(Int(point.y.rounded()))"
    }

    private static func layer(of view: View) -> CALayer {
      #if canImport(AppKit)
      return view.layer! // swiftlint:disable:this force_unwrapping
      #else
      return view.layer
      #endif
    }

    /// Lays the view out now, as a window resize does, so a changed frame renders right away where it can.
    private static func layoutNow(_ view: View) {
      #if canImport(AppKit)
      view.needsLayout = true
      view.layoutSubtreeIfNeeded()
      #else
      view.setNeedsLayout()
      view.layoutIfNeeded()
      #endif
    }

    /// Runs the block on the next main run loop iteration, after the blocks the framework queued before it.
    private static func afterRunLoopTurn(_ block: @escaping () -> Void) {
      RunLoop.main.perform(inModes: [.common], block: block)
    }

    private static var labelColor: Color {
      #if canImport(AppKit)
      return .labelColor
      #else
      return .label
      #endif
    }

    private static var secondaryLabelColor: Color {
      #if canImport(AppKit)
      return .secondaryLabelColor
      #else
      return .secondaryLabel
      #endif
    }

    // MARK: - Constants

    enum Constants {

      /// Whether the container is a full-width panel at the bottom (iOS) instead of a window-following area (macOS).
      #if canImport(AppKit)
      static let isPanel = false
      #else
      static let isPanel = true
      #endif

      static let padding: CGFloat = 12
      static let sectionSpacing: CGFloat = 12
      static let controlSpacing: CGFloat = 6
      static let controlHeight: CGFloat = 30
      static let controlFontSize: CGFloat = 11
      static let controlsHeight: CGFloat = controlHeight * 4 + controlSpacing * 3
      static let statusFontSize: CGFloat = 11
      static let statusSpacing: CGFloat = 6
      static let statusHeight: CGFloat = 290
      static let logLineCount = 6

      static let defaultContainerSize = CGSize(width: 320, height: 260)
      static let minContainerSize: CGFloat = 120
      static let resizeStep: CGFloat = 40
      static let resizeHandleSize = isPanel ? CGSize(width: 48, height: 8) : CGSize(width: 20, height: 20)
      static let grabberSpacing: CGFloat = 6
      static let outlineWidth: CGFloat = 1

      static let rowHeight: CGFloat = 40
      static let rowSpacing: CGFloat = 8
      static let rowCornerRadius: CGFloat = 6
      static let contentPadding: CGFloat = 12
    }
  }
}
