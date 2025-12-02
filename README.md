# golden-ratio.nvim

Automatic resizing of Neovim windows to the golden ratio.

When working with many windows at the same time, each window has a size that is not convenient for editing.

**golden-ratio.nvim** helps on this issue by automatically resizing the windows you are working on to the size specified in the "Golden Ratio". The window that has the main focus will have the perfect size for editing, while the ones that are not being actively edited will be resized to a smaller size that doesn't get in the way, but at the same time will be readable enough to know its content.

This is a Neovim port of the excellent [golden-ratio.el](https://github.com/roman/golden-ratio.el) for Emacs.

For more info about the golden ratio, check out:
- https://en.wikipedia.org/wiki/Golden_ratio

## Features

- ✨ Automatic window resizing based on the golden ratio (1.618)
- 🖥️ Widescreen support with configurable adjustment factors
- 📏 Fixed maximum width for focused writing or coding
- 🎯 Smart exclusion by filetype, buffer name, or custom function
- ⚡ Lightweight and performant
- 🔧 Highly configurable

## Requirements

- Neovim >= 0.11.0

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

**Option 1: Lazy loading (recommended)**

```lua
{
  "lkzz/golden-ratio.nvim",
  lazy = true,
  keys = {
    { "<leader>wg", "<cmd>GoldenRatioToggle<cr>", desc = "Toggle golden ratio" },
    { "<leader>wr", "<cmd>GoldenRatioResize<cr>", desc = "Golden ratio resize" },
  },
  cmd = {
    "GoldenRatioEnable",
    "GoldenRatioDisable",
    "GoldenRatioToggle",
    "GoldenRatioResize",
    "GoldenRatioToggleWidescreen",
    "GoldenRatioAdjust",
  },
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the defaults
  },
}
```


## Usage

### Basic Usage

To enable automatic resizing:

```lua
require("golden-ratio").enable()
```

To disable automatic resizing:

```lua
require("golden-ratio").disable()
```

To toggle golden ratio mode:

```lua
require("golden-ratio").toggle()
```

To manually trigger resize:

```lua
require("golden-ratio").resize()
```

### Commands

The plugin provides the following commands:

- `:GoldenRatioEnable` - Enable golden ratio mode
- `:GoldenRatioDisable` - Disable golden ratio mode
- `:GoldenRatioToggle` - Toggle golden ratio mode
- `:GoldenRatioResize` - Manually trigger resize
- `:GoldenRatioToggleWidescreen` - Toggle between normal and widescreen modes
- `:GoldenRatioAdjust <factor>` - Set width adjustment factor

## Configuration

### Default Configuration

```lua
require("golden-ratio").setup({
  -- Golden ratio value
  ratio = 1.618,

  -- Width adjustment factor (1 = no adjustment)
  -- For very wide screens, 0.4-0.8 may work well
  adjust_factor = 1.0,

  -- Width adjustment factor for widescreen mode
  wide_adjust_factor = 0.8,

  -- Enable automatic width adjustment based on screen size
  -- Scales the width to be smaller as the screen gets bigger
  auto_scale = false,

  -- Set a maximum column width on the active window
  -- nil means no maximum
  max_width = nil,

  -- Recenter window when resizing
  recenter = false,

  -- Minimal width change needed to trigger actual window resizing
  minimal_width_change = 1,

  -- Minimal height change needed to trigger actual window resizing
  minimal_height_change = 1,

  -- List of filetypes to exclude from golden ratio resizing
  exclude_filetypes = {
    -- File explorers
    "NvimTree",
    "neo-tree",
    "oil",
    "nerdtree",
    -- Special windows
    "qf",
    "help",
    "man",
    "terminal",
    -- Outlines and sidebars
    "aerial",
    "Outline",
    "vista",
    "sagaoutline",
    -- Diagnostics and debugging
    "Trouble",
    "dap-repl",
    "dapui_scopes",
    "dapui_breakpoints",
    "dapui_stacks",
    "dapui_watches",
    "dapui_console",
    -- Version control
    "fugitive",
    "fugitiveblame",
    "git",
    -- Plugins
    "TelescopePrompt",
    "TelescopeResults",
    "packer",
    "lazy",
    "undotree",
    "spectre_panel",
    "toggleterm",
  },

  -- List of buffer names to exclude (supports exact match)
  exclude_buffer_names = {},

  -- List of patterns to exclude buffer names (supports Lua patterns)
  exclude_buffer_patterns = {},

  -- Custom function to determine if window should be excluded
  -- Should return true to exclude, false otherwise
  -- Signature: function(winid, bufnr) -> boolean
  exclude_func = nil,

  -- Enable debug logging
  debug = false,
})
```

### Wide Screens

If you use a large screen and have very wide frames, golden-ratio makes very wide windows. This can be handled automatically by setting `auto_scale` to `true`:

```lua
require("golden-ratio").setup({
  auto_scale = true,
})
```

This does a good job of keeping windows at a reasonable width regardless of how wide or narrow your frame size is.

For manual control, set the `adjust_factor`:

```lua
require("golden-ratio").setup({
  adjust_factor = 0.8,  -- Makes windows less wide
  wide_adjust_factor = 0.8,  -- Factor used when toggling widescreen
})
```

For a very wide screen of ~3400px, a factor of 0.4 works well, giving windows with a width of ~100 columns.

### Fixed Width

When working with files that are required to have a maximum line width or when writing text, it's sometimes good to have a fixed width on the window you are typing in:

```lua
-- For code with line width limits
require("golden-ratio").setup({
  max_width = 100,
})

-- For distraction-free writing
require("golden-ratio").setup({
  max_width = 72,
})
```

### Excluding Windows

You can exclude certain windows from golden ratio resizing:

```lua
require("golden-ratio").setup({
  -- Exclude by filetype (default already excludes common plugins)
  exclude_filetypes = { "help", "fugitive", "Trouble" },

  -- Exclude by exact buffer name
  exclude_buffer_names = { "term://", "[Command Line]" },

  -- Exclude by pattern (Lua patterns)
  exclude_buffer_patterns = { "^term://", "^diffview://" },

  -- Custom exclude function
  exclude_func = function(winid, bufnr)
    -- Example: exclude if window width is too small
    local width = vim.api.nvim_win_get_width(winid)
    if width < 30 then
      return true
    end
    return false
  end,
})
```

## API

The plugin exposes the following Lua API:

```lua
local gr = require("golden-ratio")

-- Setup with configuration
gr.setup(config)

-- Enable/disable
gr.enable()
gr.disable()
gr.toggle()
gr.is_enabled()  -- returns boolean

-- Manual resize
gr.resize()

-- Widescreen controls
gr.toggle_widescreen()
gr.set_adjust_factor(0.8)
```

## How It Works

The plugin uses Neovim's autocommands to detect when you switch windows:

1. **WinEnter** - Triggered when entering a window
2. **VimResized** - Triggered when Neovim is resized
3. **BufWinEnter** - Triggered when a buffer enters a window (for splits)

When triggered:
1. Calculates target dimensions based on golden ratio (1.618)
2. Checks exclusion rules (filetypes, buffer names, custom functions)
3. Balances all windows first with `:wincmd =`
4. Resizes the active window to golden ratio dimensions
5. Other windows automatically adjust to fill remaining space

## Credits

- Original Emacs plugin: [golden-ratio.el](https://github.com/roman/golden-ratio.el) by [Roman Gonzalez](https://github.com/roman)
- Code inspired by ideas from [Tatsuhiro Ujihisa](http://twitter.com/ujm)
