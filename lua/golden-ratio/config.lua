-- Configuration module for golden-ratio.nvim
local M = {}

-- Default configuration
M.defaults = {
  -- Golden ratio value
  ratio = 1.618,

  -- Width adjustment factor (1 = no adjustment)
  -- For very wide screens/frames, 0.4-0.8 may work well
  adjust_factor = 1.0,

  -- Width adjustment factor for widescreen mode
  wide_adjust_factor = 0.8,

  -- Enable automatic width adjustment based on frame size
  -- Scales the width to be smaller as the frame gets bigger
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
}

-- Current configuration (merged defaults with user config)
M.options = vim.deepcopy(M.defaults)

-- Setup configuration with user options
---@param user_config table|nil User configuration to merge with defaults
function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_config or {})

  if M.options.debug then
    vim.notify("golden-ratio.nvim: Configuration loaded", vim.log.levels.INFO)
  end
end

-- Get current configuration
---@return table Current configuration
function M.get()
  return M.options
end

-- Update a single configuration option
---@param key string Configuration key
---@param value any New value
function M.set(key, value)
  if M.options[key] ~= nil then
    M.options[key] = value
  else
    vim.notify(
      string.format("golden-ratio.nvim: Unknown configuration key '%s'", key),
      vim.log.levels.WARN
    )
  end
end

return M
