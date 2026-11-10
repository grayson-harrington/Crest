import SwiftUI

struct BrowserRootPeekLayer: View {
    let model: BrowserRootModel
    let transientBrowsing: BrowserTransientBrowsingCoordinator
    let space: SpaceModel
    /// Whether the pages meet a docked sidebar, which leaves no frame on that
    /// edge.
    let docked: Bool

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack {
            peeks
        }
        // A Peek on its way out, or hidden behind another tab, stops covering
        // as soon as it is no longer shown, not when its fade ends.
        .onChange(of: shownRequests.map(\.id)) { previous, current in
            for requestID in previous where !current.contains(requestID) {
                model.clearPeekCardFrame(for: requestID)
            }
        }
    }

    private var peeks: some View {
        ForEach(shownRequests) { request in
            BrowserPeekOverlay(
                request: request,
                browser: model.browser,
                pages: model.pages,
                coordinator: transientBrowsing,
                reservedLeadingWidth: 0,
                layoutDirection: layoutDirection,
                spaceAccess: model.spaceAccess,
                frameInsets: BrowserChromeAppearance.device(windowCornerRadius: nil)
                    .pageInsets(docked: docked, direction: layoutDirection)
            )
            .environment(
                \.browserWebFocusRestorationGate,
                BrowserWebFocusRestorationGate(
                    browserChromeOwnsFocus: !request.isSelected(in: model.browser), pageChromeOwnsFocus: false)
            )
            // What the card covers keeps Split View from handing the pointer
            // to the pane beneath it.
            .environment(\.browserTransientCardFrameReport) { frames in
                model.recordPeekCardFrames(frames, for: request)
            }
            .onDisappear { model.clearPeekCardFrame(for: request.id) }
            .zIndex(BrowserRootMetrics.peekZIndex)
        }
    }

    /// The Peeks this Space shows: those over its selected tab.
    private var shownRequests: [BrowserPeekRequest] {
        transientBrowsing.peekRequests.filter {
            $0.assignment == BrowserSpaceRuntimeAssignment(space: space)
                && $0.sourceTabID == model.browser.selectedTabID(in: space.id)
        }
    }
}
