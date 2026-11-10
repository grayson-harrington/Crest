import AppKit
import XCTest

@testable import Crest

/// Split View hands the pointer to the card under it only where nothing is
/// drawn over that card. The floating sidebar and a Peek opened from one card
/// both reach over others, and a press or hover on them belongs to them: it
/// must not focus the card beneath, which would hide the Peek or point Site
/// Controls at the wrong page.
@MainActor
final class BrowserSplitCoveredFocusTests: XCTestCase {
    // MARK: - Static Variables

    private static let leadingCard = CGRect(x: 0, y: 0, width: 400, height: 600)
    private static let trailingCard = CGRect(x: 400, y: 0, width: 400, height: 600)
    /// A Peek opened from the leading card, reaching over the trailing one.
    private static let peekCard = CGRect(x: 200, y: 100, width: 400, height: 400)
    /// The Peek's buttons, above the card's trailing corner.
    private static let peekControls = CGRect(x: 520, y: 60, width: 80, height: 30)
    private static let peekFrames = [peekCard, peekControls]
    private static let leadingID = UUID()
    private static let trailingID = UUID()

    // MARK: - Press

    func testPressOnChromeOverACardFocusesNothing() {
        let observer = makeObserver(covering: Self.peekCard)
        XCTAssertNil(observer.card(pressedAt: CGPoint(x: 500, y: 300)))
        XCTAssertNil(observer.card(pressedAt: CGPoint(x: 300, y: 300)))
    }

    func testPressOnAnUncoveredPartOfACardFocusesIt() {
        let observer = makeObserver(covering: Self.peekCard)
        XCTAssertEqual(observer.card(pressedAt: CGPoint(x: 700, y: 300)), Self.trailingID)
        XCTAssertEqual(observer.card(pressedAt: CGPoint(x: 500, y: 550)), Self.trailingID)
        XCTAssertEqual(observer.card(pressedAt: CGPoint(x: 100, y: 300)), Self.leadingID)
    }

    // MARK: - Hover

    func testHoverOnChromeOverACardLeavesFocus() {
        XCTAssertFalse(focusesOnHover(isPointerCovered: true))
        XCTAssertTrue(focusesOnHover(isPointerCovered: false))
    }

    // MARK: - What covers

    func testShownPeekCoversOnlyItsCardAndButtons() throws {
        let model = makeModel()
        let request = try peek(over: XCTUnwrap(model.browser.shownTab?.id), in: model)
        model.recordPeekCardFrames(Self.peekFrames, for: request)

        XCTAssertTrue(model.chromeCovers(CGPoint(x: 500, y: 300)))
        XCTAssertTrue(model.chromeCovers(CGPoint(x: 560, y: 75)))
        XCTAssertFalse(model.chromeCovers(CGPoint(x: 700, y: 300)))
        // Beside the buttons, above the card, is the dimmed ground around it.
        XCTAssertFalse(model.chromeCovers(CGPoint(x: 450, y: 75)))
    }

    func testClosedPeekNoLongerCovers() throws {
        let model = makeModel()
        let request = try peek(over: XCTUnwrap(model.browser.shownTab?.id), in: model)
        model.recordPeekCardFrames(Self.peekFrames, for: request)
        model.clearPeekCardFrame(for: request.id)

        XCTAssertFalse(model.chromeCovers(CGPoint(x: 500, y: 300)))
    }

    /// A Peek over a tab the window is not showing, such as one in a Space
    /// drawn beside the shown one, covers nothing.
    func testPeekOverAnotherTabDoesNotCover() throws {
        let model = makeModel()
        let shown = try XCTUnwrap(model.browser.shownTab?.id)
        let other = try XCTUnwrap(model.browser.shownSpace?.tabIDs.first { $0 != shown })
        model.recordPeekCardFrames(Self.peekFrames, for: try peek(over: other, in: model))

        XCTAssertFalse(model.chromeCovers(CGPoint(x: 500, y: 300)))
    }

    func testFloatingSidebarCoversButCollapsedDoesNot() {
        let model = makeModel()
        let sidebar = CGRect(x: 0, y: 0, width: 260, height: 600)
        model.recordSidebarSurfaceFrame(sidebar)
        model.chrome.columnVisibility = .detailOnly

        model.isFloatingSidebarPresented = true
        XCTAssertTrue(model.chromeCovers(CGPoint(x: 100, y: 300)))
        XCTAssertFalse(model.chromeCovers(CGPoint(x: 300, y: 300)))

        model.isFloatingSidebarPresented = false
        XCTAssertFalse(model.chromeCovers(CGPoint(x: 100, y: 300)))
    }

    // MARK: - Mutators

    private func makeObserver(covering cover: CGRect) -> BrowserSplitCardPointerObserverView {
        let frames = BrowserSplitCardFrameRegistry()
        frames.register(Self.leadingCard, for: Self.leadingID)
        frames.register(Self.trailingCard, for: Self.trailingID)
        return BrowserSplitCardPointerObserverView(
            cardFrames: frames,
            handleMouseDown: { _ in },
            lift: BrowserSplitCardLiftGesture(
                begin: { _, _ in false }, update: { _ in }, drop: {}, cancel: {}, isCarrying: { false }),
            isCovered: { cover.contains($0) }
        )
    }

    private func focusesOnHover(isPointerCovered: Bool) -> Bool {
        BrowserSplitPageSurface.focusesOnHover(
            followsMouse: true,
            isCardFocused: false,
            isPointerCovered: isPointerCovered,
            isAddressEditing: false,
            isDraggingSidebarItem: false,
            isCarryingCard: false,
            isCommandPalettePresented: false
        )
    }

    private func peek(over tabID: UUID, in model: BrowserRootModel) throws -> BrowserPeekRequest {
        let space = try XCTUnwrap(model.browser.shownSpace)
        return BrowserPeekRequest(
            url: try XCTUnwrap(URL(string: "about:blank")),
            sourceTabID: tabID,
            sourceTitle: space.settings.name,
            spaceAssignment: BrowserSpaceRuntimeAssignment(space: space),
            trigger: .modifierClick
        )
    }

    /// A window over one Space showing Alpha, with Beta beside it.
    private func makeModel() -> BrowserRootModel {
        let alpha = TabState.Seed(title: "Alpha", url: URL(string: "https://alpha.crest.test"), placement: .current)
        let beta = TabState.Seed(title: "Beta", url: URL(string: "https://beta.crest.test"), placement: .current)
        let space = SpaceState.Seed(name: "Test", symbol: "circle", accent: .indigo, folders: [], tabs: [alpha, beta])
        let browser = BrowserStore.hostingPages(SessionState.Seed(spaces: [space]))
        let spaceAccess = BrowserSpaceAccessController(authenticator: BrowserPreviewAuthenticator(result: true))
        browser.attachSpaceAccess(spaceAccess)
        return BrowserRootModel(
            browser: browser,
            pages: BrowserPagePool(browser: browser),
            chrome: BrowserChromeState(),
            spaceAccess: spaceAccess,
            windowState: nil, startupBehavior: .lastActiveTab,
            persistedSidebarWidth: BrowserChromeLayout.sidebarIdealWidth
        )
    }
}
