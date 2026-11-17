import Foundation

struct BrowserCredentialFillRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let origin: CredentialOrigin
    let topLevelOrigin: CredentialOrigin
    let usernameHint: String?

    /// The kind of password field the request fills, or nil when it came from
    /// a username field on a step that asks for the username alone.
    let passwordKind: CredentialPasswordKind?

    /// Whether a username field asked rather than a password field. Such a
    /// request shows a prompt only where the Space holds a password for the
    /// site, so an email field anywhere never raises an empty one.
    let focusesUsername: Bool
    let isCrossOriginFrame: Bool
    let requestedAt: Date

    /// Where the field that asked sits in the page's viewport, in CSS pixels,
    /// or `nil` where nothing can be said about it.
    ///
    /// Only a main-frame field ever fills this in. A subframe reports its rect
    /// in its own viewport, and a cross-origin one cannot know where that
    /// viewport lands in the page — so a prompt raised from a frame keeps the
    /// placement it has always had rather than pointing at the wrong place.
    let fieldRect: BrowserCredentialFieldRect?

    init(
        id: UUID,
        origin: CredentialOrigin,
        topLevelOrigin: CredentialOrigin,
        usernameHint: String?,
        passwordKind: CredentialPasswordKind?,
        focusesUsername: Bool = false,
        isCrossOriginFrame: Bool,
        requestedAt: Date,
        fieldRect: BrowserCredentialFieldRect? = nil
    ) {
        self.id = id
        self.origin = origin
        self.topLevelOrigin = topLevelOrigin
        self.usernameHint = usernameHint
        self.passwordKind = passwordKind
        self.focusesUsername = focusesUsername
        self.isCrossOriginFrame = isCrossOriginFrame
        self.requestedAt = requestedAt
        self.fieldRect = fieldRect
    }

    /// The same request, following its field to where the page just moved it.
    ///
    /// Everything the prompt is identified and guarded by — its ID above all —
    /// is carried through unchanged, so a scroll moves the panel without
    /// re-asking the vault or re-arming any of the fill guards.
    func following(_ fieldRect: BrowserCredentialFieldRect) -> Self {
        BrowserCredentialFillRequest(
            id: id,
            origin: origin,
            topLevelOrigin: topLevelOrigin,
            usernameHint: usernameHint,
            passwordKind: passwordKind,
            focusesUsername: focusesUsername,
            isCrossOriginFrame: isCrossOriginFrame,
            requestedAt: requestedAt,
            fieldRect: fieldRect
        )
    }
}
