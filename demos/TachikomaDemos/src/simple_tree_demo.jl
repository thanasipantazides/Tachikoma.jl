# ═══════════════════════════════════════════════════════════════════════
# Simple Tree Demo ── debug of TreeView, displaying node info and row
# 
# arrow keys to navigate, [q] quit
# ═══════════════════════════════════════════════════════════════════════

using Base: @kwdef


function build_tree()
    root = TreeNode("System", 
        [
            TreeNode("Component", 
                [TreeNode("thing"), TreeNode("A"), TreeNode("C")]
            ), 
            TreeNode("Component", 
                [TreeNode("thing"), TreeNode("B"), TreeNode("D")]
            ), 
            TreeNode("Another component", 
                [TreeNode("thing"), TreeNode("E")]
            )
        ]
    )
    return TreeView(root; indent=4, connector_style=tstyle(:border, dim=true), show_root=false)
end

@kwdef mutable struct TreeState <: Model
    quit::Bool = false
    do_modal::Bool = false
    tick::UInt = 0
    file::String = default_fsource
    counter::UInt64 = 0
    tree::TreeView = build_tree()
    outer_layout::ResizableLayout = ResizableLayout(Horizontal, [Fixed(30), Fill()])
end

should_quit(m::TreeState) = m.quit

function update!(m::TreeState, event::KeyEvent)
    if event.key == :char && event.char == 'q'
        m.quit = true
        return
    end
    handle_key!(m.tree, event)
end

function update!(m::TreeState, event::MouseEvent)
    handle_mouse!(m.tree, event)
end

function view(m::TreeState, f::Frame)
    m.tick += 1
    rects = split_layout(m.outer_layout, f.area)

    innerL = render(Block(title="Tree", box=BOX_PLAIN), rects[1], f.buffer)
    innerR = render(Block(title="Debug", box=BOX_PLAIN), rects[2], f.buffer)

    spn = Paragraph("value: $(value(m.tree))\nvalue_node: $(Tachikoma.value_node(m.tree))", wrap=char_wrap)

    render(m.tree, innerL, f.buffer)
    render(spn, innerR, f.buffer)
end

function simple_tree_demo(; theme_name=nothing)
    theme_name !== nothing && set_theme!(theme_name)
    return app(TreeState(); fps=30)
end