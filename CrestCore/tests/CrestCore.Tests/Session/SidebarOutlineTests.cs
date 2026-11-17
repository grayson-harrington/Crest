using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

/// The outline a Space's sidebar lists: which rows each section and folder
/// holds, in what order, how splits fold, and what a person sees of it.
public sealed class SidebarOutlineTests {
    #region Static Variables

    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-09-25T12:00:00Z");

    #endregion

    #region Actions - Folding

    /// A contiguous run of one split's tabs is one row that shows them in order; a
    /// lone member shows as a plain tab, and every other tab keeps its place.
    [Fact]
    public void ARunOfOneSplitIsOneRowAndALoneMemberStaysATab() {
        var group = Guid.NewGuid();
        var lone = Guid.NewGuid();
        var leading = Tab("leading");
        var head = Tab("head", split: group);
        var tail = Tab("tail", split: group);
        var single = Tab("single", split: lone);
        var trailing = Tab("trailing");

        var rows = Top(SidebarOutline.Of([leading, head, tail, single, trailing], []), TabPlacement.Current).Rows;

        Assert.Equal([leading.Id, group, single.Id, trailing.Id], rows.Select(row => row.Id));
        Assert.Equal([SidebarRowKind.Tab, SidebarRowKind.Split, SidebarRowKind.Tab, SidebarRowKind.Tab], rows.Select(row => row.Kind));
        Assert.Equal([head.Id, tail.Id], rows[1].Members);
        Assert.Equal([single.Id], rows[2].Members);
        Assert.Equal([leading.Id, head.Id, tail.Id, single.Id, trailing.Id], rows.SelectMany(row => row.Listed));
    }

    #endregion

    #region Actions - Folders

    /// Next and previous tab stop on the tabs a collapsed folder keeps on screen
    /// under its header, inside folders it holds too, and pass over the tabs it
    /// hides; a collapsed section hides the tabs its folders keep.
    [Fact]
    public void SteppingStopsOnTheTabsACollapsedFolderKeepsOnScreen() {
        var outer = Folder("outer", TabPlacement.Current, collapsed: true);
        var inner = Folder("inner", TabPlacement.Current, outer.Id, collapsed: true);
        var reading = Folder("reading", TabPlacement.Saved, collapsed: true);
        var above = Tab("above");
        var kept = Tab("kept", folder: outer.Id);
        var hidden = Tab("hidden", folder: outer.Id);
        var nested = Tab("nested", folder: inner.Id);
        var below = Tab("below");
        var saved = Tab("saved", TabPlacement.Saved, reading.Id);
        var outline = SidebarOutline.Of([saved, above, kept, hidden, nested, below], [outer, inner, reading]);
        FolderState[] folders = [outer, inner, reading];
        HashSet<Guid> keeping = [kept.Id, nested.Id, saved.Id];
        Guid? Step(TabState from, AdjacentDirection direction, bool savedExpanded = false) =>
            outline.Step(from.Id, direction, folders, section => !section.IsCollapsible || savedExpanded, keeping);

        Assert.Equal(kept.Id, Step(above, AdjacentDirection.Next));
        Assert.Equal(nested.Id, Step(kept, AdjacentDirection.Next));
        Assert.Equal(below.Id, Step(nested, AdjacentDirection.Next));
        Assert.Equal(nested.Id, Step(below, AdjacentDirection.Previous));
        Assert.Equal(above.Id, Step(kept, AdjacentDirection.Previous));
        Assert.Equal(nested.Id, Step(hidden, AdjacentDirection.Next));
        Assert.Equal(saved.Id, Step(above, AdjacentDirection.Previous, savedExpanded: true));
        Assert.Equal(below.Id, Step(above, AdjacentDirection.Previous));
    }

    #endregion

    #region Actions - Order

    /// A selection is ordered as the Space's outline lists it: the tabs of a Space
    /// with pinned tabs, nested and empty folders, a split and a Start Page come back
    /// in the order the sidebar lists them, whatever order they were picked in.
    [Fact]
    public void ASelectionIsOrderedAsTheOutlineLists() {
        var group = Guid.NewGuid();
        var projects = Folder("projects", TabPlacement.Saved);
        var reading = Folder("reading", TabPlacement.Saved, projects.Id);
        var errands = Folder("errands", TabPlacement.Current);
        TabState[] tabs = [
            Tab("pinned", TabPlacement.Pinned), Tab("loose saved", TabPlacement.Saved), Tab("article", TabPlacement.Saved, reading.Id),
            Tab("plan", TabPlacement.Saved, projects.Id), Tab("draft", startPage: true), Tab("head", split: group),
            Tab("tail", split: group), Tab("errand", folder: errands.Id), Tab("last")
        ];
        FolderState[] folders = [errands, projects, reading, Folder("empty", TabPlacement.Current, anchor: tabs[5].Id)];
        var space = BrowserTabCollection.Restore(tabs, folders, []);
        var outline = SidebarOutline.Of(space.TabStates, space.Folders);
        var listed = outline.Positions().Keys.ToList();
        Guid[] picked = [.. listed.Where(id => tabs.Any(tab => tab.Id == id)).Reverse()];

        var selected = space.Select(new TabSelection(picked, [], picked));

        Assert.Equal(listed.Where(picked.Contains), selected.Roots.Select(root => root.Id));
        Assert.Equal(listed.Count, tabs.Length - 1 + folders.Length);
    }

    #endregion

    #region Actions - Support

    private static TabState Tab(string title, TabPlacement? placement = null, Guid? folder = null, Guid? split = null,
        bool startPage = false) {
        var section = placement ?? TabPlacement.Current;
        string? url = startPage ? null : $"https://example.com/{Uri.EscapeDataString(title)}";
        return new(Guid.NewGuid(), title, url, null, section.IsDurable ? url : null, "globe", null, null, null, section, folder, split,
            Now, null, null, null, false);
    }

    private static FolderState Folder(string title, TabPlacement location, Guid? parent = null, Guid? anchor = null,
        bool collapsed = false) =>
        new(Guid.NewGuid(), location, title, ParentId: parent, IsCollapsed: collapsed, OrderAnchorTabId: anchor);

    private static SidebarList Top(SidebarOutline outline, TabPlacement section) =>
        outline.Lists.Single(list => list.FolderId is null && list.Section == section);

    #endregion
}
