using CrestCore.Application;

namespace CrestCore.Contracts;

/// Reports whether one window is on the current macOS desktop. A window away
/// on another desktop or behind a full-screen app keeps showing its tabs, and
/// they keep their pages, but the person cannot see them: a video one of them
/// floated in Picture in Picture goes back into its page once the window is
/// on the person's desktop again, as it does when they come back to its tab.
public sealed record ReportWindowOnDesktop(Guid WindowId, bool IsOnDesktop) : WindowIntent {
    #region Actions - Device

    internal override void Apply(Device device, DeviceTurn turn) {
        var window = device.Opened(WindowId);
        lock (device.Gate) window.IsOnDesktop = IsOnDesktop;
    }

    #endregion
}
