# Tiling Panes (PanelTree)

`PanelTree` tiles widgets into a tree of non-overlapping, resizable panes. It is
the tiling counterpart to the [`WindowManager`](window-manager.md): instead of
floating windows that overlap, a `PanelTree` always partitions the full area, so
every pane gets a dedicated slot. Panes can be split, focused, closed, dragged to
a new position, docked against another pane's edge, and resized by their dividers
— all while still forwarding keyboard and mouse input to their content widgets.

## When to use this

Use `PanelTree` when your UI is a set of panels that should tile rather than
float:

- IDE-style layouts: an editor next to a file tree and a terminal
- Dashboards where each panel owns a fixed, non-overlapping region
- Split views the user can rearrange, resize, and grow/shrink at runtime

If you want overlapping, desktop-style windows, use [`WindowManager`](window-manager.md)
instead. If you want a fixed, non-interactive arrangement, prefer the
container-based layouts in [`layout.md`](layout.md).

## Basic pieces

A `PanelTree` owns a tree of panes:

- A **`PaneLeaf`** holds one piece of `content` and an optional `title`.
- A **`PaneSplit`** arranges child panes along an axis with draggable dividers.

`content` is anything that renders — a widget with `render(w, rect, buf)` (and
optionally `handle_key!` / `handle_mouse!`), or a [`Model`](architecture.md)
(rendered via `view`, driven via `update!`). Construct a tree from a single
starting pane:

```julia
pt = Tachikoma.PanelTree(my_widget; title="main", chrome=:bars)
```

- `chrome=:bars` draws a title bar on each pane; the focused pane is marked with a
  focus ring. Pass `chrome=:none` for borderless panes.
- `alive` lets the tree prune panes whose content has exited (see [`prune!`](#api-summary)).

## Tiling demo

Splitting the focused pane right (`s`) and down (`v`), cycling focus (`f`), then
dragging the editor pane's title bar across to dock it on another pane's edge —
the drop preview follows the cursor and the layout re-tiles on release:

<!-- tachi:app panel_tree_demo w=64 h=20 frames=210 fps=15 -->
```julia
import Tachikoma
using Match

# Each pane just holds a scrollable list so the splits are easy to tell apart.
_pane(name) = Tachikoma.ScrollPane(["$name · line $i" for i in 1:12]; following=false)

@kwdef mutable struct _PTAnim <: Tachikoma.Model
    pt::Tachikoma.PanelTree = Tachikoma.PanelTree(_pane("editor"); title="editor")
    n::Int = 1
end

# Keys split / focus / close the panes; anything else falls through to the
# focused pane's own widget.
function Tachikoma.update!(m::_PTAnim, evt::Tachikoma.KeyEvent)
    @match (evt.key, evt.char) begin
        (:char, 's') => (m.n += 1; Tachikoma.split_pane!(m.pt, _pane("pane $(m.n)"); horizontal=true,  title="pane $(m.n)"))
        (:char, 'v') => (m.n += 1; Tachikoma.split_pane!(m.pt, _pane("pane $(m.n)"); horizontal=false, title="pane $(m.n)"))
        (:char, 'f') => Tachikoma.focus_next!(m.pt)
        (:char, 'w') => Tachikoma.close_pane!(m.pt)
        _            => Tachikoma.handle_key!(m.pt, evt)
    end
end

# Mouse drives move / dock / resize directly.
Tachikoma.update!(m::_PTAnim, evt::Tachikoma.MouseEvent) = Tachikoma.handle_mouse!(m.pt, evt)

Tachikoma.view(m::_PTAnim, f::Tachikoma.Frame) = Tachikoma.render(m.pt, f.area, f.buffer)

Tachikoma.app(_PTAnim())
```

## Commands

`PanelTree` deliberately has **no built-in key bindings** — `handle_key!`
forwards straight to the focused pane's content, so the application owns every
command. Wire these into your `update!`:

<!-- tachi:noeval -->
```julia
split_pane!(pt, content; horizontal=true)   # split focused pane; true = side-by-side, false = stacked
focus_next!(pt); focus_prev!(pt)            # cycle focus between panes
close_pane!(pt)                             # close the focused pane (never the last one)
focused_pane(pt); focused_content(pt)       # the focused leaf / its content
panes(pt); pane_count(pt)                   # all leaves (left→right, top→bottom) / their count
```

`split_pane!` inserts the new pane beside the focused one and focuses it, then
returns the new `PaneLeaf`. `close_pane!` collapses the surrounding split so the
remaining panes reclaim the space, and refuses to close the final pane.

## Mouse: move, dock, and resize

`handle_mouse!` gives you direct manipulation with no extra wiring:

- **Move** — drag a pane's title bar; a drop preview follows the cursor.
- **Dock** — release over another pane's edge (left/right/top/bottom) to re-split
  and dock there, or over its center to swap the two panes' contents.
- **Resize** — drag a divider between panes to grow one and shrink its neighbour.
- **Focus** — click any pane to focus it.

`is_moving(pt)` reports whether a drag is in progress, and `cancel_move!(pt)`
aborts it (e.g. on `Escape`).

## Forwarding input

The integration is the same shape as any container widget — forward events in
`update!` and render in `view`:

<!-- tachi:noeval -->
```julia
function Tachikoma.update!(m::MyModel, evt::Tachikoma.Event)
    evt isa Tachikoma.KeyEvent   && Tachikoma.handle_key!(m.pt, evt)
    evt isa Tachikoma.MouseEvent && Tachikoma.handle_mouse!(m.pt, evt)
end

function Tachikoma.view(m::MyModel, f::Tachikoma.Frame)
    Tachikoma.render(m.pt, f.area, f.buffer)
end
```

Content widgets keep their own key and mouse bindings — `PanelTree` forwards
events to the focused pane transparently.

## API summary

- `PanelTree(content; title="", chrome=:bars, alive=nothing)`
- `split_pane!(pt, content; horizontal=true, title="", after=true, at=focused_pane(pt))` → `PaneLeaf`
- `close_pane!(pt, leaf=focused_pane(pt))` → `Bool`
- `focus_next!(pt)`, `focus_prev!(pt)`
- `focused_pane(pt)`, `focused_content(pt)`
- `panes(pt)`, `pane_count(pt)`
- `prune!(pt)` — drop panes whose content has exited (per `alive`); returns `false` when all are dead
- `is_moving(pt)`, `cancel_move!(pt)`
- `handle_key!(pt, evt)`, `handle_mouse!(pt, evt)`, `render(pt, area, buf)`
