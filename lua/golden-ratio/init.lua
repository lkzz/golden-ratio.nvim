-- golden-ratio.nvim: Automatic resizing of Neovim windows to the golden ratio
local config = require("golden-ratio.config")

local M = {}

-- Plugin state
local enabled = false
local autocmd_group = nil

-- Log debug message
---@param msg string Debug message
local function debug_log(msg)
  if config.get().debug then
    vim.notify("golden-ratio.nvim: " .. msg, vim.log.levels.DEBUG)
  end
end

-- Calculate scale factor based on current configuration
---@return number Scale factor for width adjustment
local function calculate_scale_factor()
  local opts = config.get()
  if opts.auto_scale then
    local columns = vim.o.columns
    -- Scale factor decreases as screen gets wider
    -- For a 100 column screen, factor = 1.0
    -- For larger screens, factor decreases
    return math.max(0.4, 1.0 - ((columns - 100) / 1000.0) * 1.8)
  else
    return opts.adjust_factor
  end
end

-- Check if a buffer should be excluded from resizing
---@param bufnr number Buffer number
---@param winid number Window ID
---@return boolean True if should be excluded
local function should_exclude_buffer(bufnr, winid)
  local opts = config.get()

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return true
  end

  -- Get buffer info
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype

  -- Check excluded filetypes
  if vim.tbl_contains(opts.exclude_filetypes, filetype) then
    debug_log(string.format("Excluded by filetype: %s", filetype))
    return true
  end

  -- Check excluded buffer names (exact match)
  if vim.tbl_contains(opts.exclude_buffer_names, bufname) then
    debug_log(string.format("Excluded by buffer name: %s", bufname))
    return true
  end

  -- Check excluded buffer patterns
  for _, pattern in ipairs(opts.exclude_buffer_patterns) do
    if bufname:match(pattern) then
      debug_log(string.format("Excluded by pattern: %s matches %s", bufname, pattern))
      return true
    end
  end

  -- Check custom exclude function
  if opts.exclude_func and type(opts.exclude_func) == "function" then
    local excluded = opts.exclude_func(winid, bufnr)
    if excluded then
      debug_log("Excluded by custom function")
      return true
    end
  end

  return false
end

-- Calculate available space excluding excluded windows
---@param current_winid number Current window ID
---@param excluded_windows table Pre-collected excluded windows info
---@return number, number Available lines and columns
local function calculate_available_space(current_winid, excluded_windows)
  local total_lines = vim.o.lines
  local total_columns = vim.o.columns

  -- Get current window position and size
  local curr_pos = vim.api.nvim_win_get_position(current_winid)
  local curr_height = vim.api.nvim_win_get_height(current_winid)
  local curr_width = vim.api.nvim_win_get_width(current_winid)
  local curr_row_start = curr_pos[1]
  local curr_row_end = curr_pos[1] + curr_height
  local curr_col_start = curr_pos[2]
  local curr_col_end = curr_pos[2] + curr_width

  local excluded_width = 0
  local excluded_height = 0

  -- Use pre-collected excluded windows info
  for _, win_info in pairs(excluded_windows) do
    -- Check if windows overlap in row range (vertical split - side by side)
    local row_overlap = (win_info.row_start < curr_row_end) and (curr_row_start < win_info.row_end)
    if row_overlap then
      excluded_width = excluded_width + win_info.width
      debug_log(string.format("Excluded window width: %d (row overlap)", win_info.width))
    end

    -- Check if windows overlap in column range (horizontal split - stacked)
    local col_overlap = (win_info.col_start < curr_col_end) and (curr_col_start < win_info.col_end)
    if col_overlap then
      excluded_height = excluded_height + win_info.height
      debug_log(string.format("Excluded window height: %d (col overlap)", win_info.height))
    end
  end

  local available_columns = total_columns - excluded_width
  local available_lines = total_lines - excluded_height

  debug_log(string.format("Available space: %dx%d (excluded: %dx%d)", available_lines, available_columns, excluded_height, excluded_width))

  return available_lines, available_columns
end

-- Calculate target dimensions for the active window
---@param winid number Window ID
---@param excluded_windows table Pre-collected excluded windows info
---@return number, number Target height and width
local function calculate_dimensions(winid, excluded_windows)
  local opts = config.get()
  local ratio = opts.ratio

  -- Calculate available space excluding excluded windows
  local available_lines, available_columns = calculate_available_space(winid, excluded_windows)

  -- Calculate target height and width based on golden ratio
  local target_height = math.floor(available_lines / ratio)
  local target_width = math.floor((available_columns / ratio) * calculate_scale_factor())

  -- Apply max width constraint if set
  if opts.max_width and opts.max_width > 0 then
    target_width = math.min(opts.max_width, target_width)
  end

  debug_log(string.format("Target dimensions: %dx%d", target_height, target_width))
  return target_height, target_width
end

-- Detect window layout relative to current window
---@param winid number Window ID to check
---@return boolean, boolean has_horizontal_split, has_vertical_split
local function detect_layout(winid)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local normal_windows = vim.tbl_filter(function(win)
    local cfg = vim.api.nvim_win_get_config(win)
    return cfg.relative == ""
  end, wins)

  if #normal_windows <= 1 then
    return false, false
  end

  -- Get current window position and size
  local curr_pos = vim.api.nvim_win_get_position(winid)
  local curr_height = vim.api.nvim_win_get_height(winid)
  local curr_width = vim.api.nvim_win_get_width(winid)
  local curr_row = curr_pos[1]
  local curr_col = curr_pos[2]

  local has_horizontal = false
  local has_vertical = false

  -- Check each window to see if it's adjacent to current window
  for _, win in ipairs(normal_windows) do
    if win ~= winid then
      local pos = vim.api.nvim_win_get_position(win)
      local height = vim.api.nvim_win_get_height(win)
      local width = vim.api.nvim_win_get_width(win)
      local row = pos[1]
      local col = pos[2]

      -- Check if windows are in the same row (side by side = vertical split)
      -- Windows are in same row if their row positions overlap
      local row_overlap = (row < curr_row + curr_height) and (curr_row < row + height)
      if row_overlap and col ~= curr_col then
        has_vertical = true
      end

      -- Check if windows are in the same column (stacked = horizontal split)
      -- Windows are in same column if their column positions overlap
      local col_overlap = (col < curr_col + curr_width) and (curr_col < col + width)
      if col_overlap and row ~= curr_row then
        has_horizontal = true
      end
    end
  end

  return has_horizontal, has_vertical
end

-- Check if golden ratio should be applied
---@param winid number|nil Window ID (defaults to current window)
---@return boolean True if should apply
local function should_apply(winid)
  winid = winid or vim.api.nvim_get_current_win()

  -- Don't resize if plugin is not enabled
  if not enabled then
    return false
  end

  -- Don't resize floating windows
  local win_config = vim.api.nvim_win_get_config(winid)
  if win_config.relative ~= "" then
    debug_log("Skipping floating window")
    return false
  end

  -- Check buffer exclusions first (before counting windows)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if should_exclude_buffer(bufnr, winid) then
    return false
  end

  -- Don't resize if only one window
  local windows = vim.api.nvim_tabpage_list_wins(0)
  local normal_windows = vim.tbl_filter(function(win)
    local cfg = vim.api.nvim_win_get_config(win)
    return cfg.relative == ""
  end, windows)

  if #normal_windows <= 1 then
    debug_log("Only one window, skipping")
    return false
  end

  return true
end

-- Get all excluded windows with their info (optimization: single pass)
---@param current_winid number Current window ID
---@return table Map of window ID to window info {width, height, pos, ...}
local function get_excluded_windows(current_winid)
  local excluded = {}
  local all_windows = vim.api.nvim_tabpage_list_wins(0)

  for _, win in ipairs(all_windows) do
    if win ~= current_winid then
      local win_config = vim.api.nvim_win_get_config(win)
      if win_config.relative == "" then  -- Only normal windows
        local bufnr = vim.api.nvim_win_get_buf(win)
        if should_exclude_buffer(bufnr, win) then
          local pos = vim.api.nvim_win_get_position(win)
          local height = vim.api.nvim_win_get_height(win)
          local width = vim.api.nvim_win_get_width(win)

          excluded[win] = {
            width = width,
            height = height,
            row_start = pos[1],
            row_end = pos[1] + height,
            col_start = pos[2],
            col_end = pos[2] + width,
          }
        end
      end
    end
  end

  return excluded
end

-- Resize window to golden ratio dimensions
---@param winid number|nil Window ID (defaults to current window)
local function resize_window(winid)
  winid = winid or vim.api.nvim_get_current_win()

  if not should_apply(winid) then
    return
  end

  -- Get all excluded windows info in a single pass
  local excluded_windows = get_excluded_windows(winid)

  -- Detect window layout relative to current window
  local has_horizontal, has_vertical = detect_layout(winid)

  -- Calculate target dimensions using pre-collected excluded windows
  local target_height, target_width = calculate_dimensions(winid, excluded_windows)
  local current_height = vim.api.nvim_win_get_height(winid)
  local current_width = vim.api.nvim_win_get_width(winid)
  local opts = config.get()

  -- Calculate differences
  local height_diff = target_height - current_height
  local width_diff = target_width - current_width

  debug_log(string.format(
    "Layout: hsplit=%s vsplit=%s, Current: %dx%d, Target: %dx%d, Diff: %dx%d",
    has_horizontal,
    has_vertical,
    current_height,
    current_width,
    target_height,
    target_width,
    height_diff,
    width_diff
  ))

  -- First, balance all windows
  vim.cmd("wincmd =")

  -- Apply height adjustment only if there are horizontal splits
  if has_horizontal and math.abs(height_diff) >= opts.minimal_height_change then
    local success = pcall(vim.api.nvim_win_set_height, winid, target_height)
    if not success then
      debug_log("Failed to set window height")
    else
      debug_log("Height adjusted")
    end
  end

  -- Apply width adjustment only if there are vertical splits
  if has_vertical and math.abs(width_diff) >= opts.minimal_width_change then
    local success = pcall(vim.api.nvim_win_set_width, winid, target_width)
    if not success then
      debug_log("Failed to set window width")
    else
      debug_log("Width adjusted")
    end
  end

  -- Restore sizes of excluded windows (use pre-collected info)
  for win, info in pairs(excluded_windows) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_width, win, info.width)
      pcall(vim.api.nvim_win_set_height, win, info.height)
      debug_log(string.format("Restored excluded window %d size: %dx%d", win, info.height, info.width))
    end
  end

  -- Recenter if configured
  if opts.recenter then
    vim.cmd("normal! zz")
  end
end

-- Setup the plugin
---@param user_config table|nil User configuration
function M.setup(user_config)
  config.setup(user_config or {})
  debug_log("Plugin setup complete")

  -- Register commands for lazy loading
  M._register_commands()
end

-- Register user commands
function M._register_commands()
  -- Prevent duplicate registration
  if vim.g.golden_ratio_commands_registered then
    return
  end
  vim.g.golden_ratio_commands_registered = true

  vim.api.nvim_create_user_command("GoldenRatioEnable", function()
    M.enable()
  end, { desc = "Enable golden ratio mode" })

  vim.api.nvim_create_user_command("GoldenRatioDisable", function()
    M.disable()
  end, { desc = "Disable golden ratio mode" })

  vim.api.nvim_create_user_command("GoldenRatioToggle", function()
    M.toggle()
  end, { desc = "Toggle golden ratio mode" })

  vim.api.nvim_create_user_command("GoldenRatioResize", function()
    M.resize()
  end, { desc = "Manually trigger golden ratio resize" })

  vim.api.nvim_create_user_command("GoldenRatioToggleWidescreen", function()
    M.toggle_widescreen()
  end, { desc = "Toggle widescreen mode" })

  vim.api.nvim_create_user_command("GoldenRatioAdjust", function(opts)
    local factor = tonumber(opts.args)
    if not factor then
      vim.notify(
        "golden-ratio.nvim: Invalid factor. Usage: :GoldenRatioAdjust <number>",
        vim.log.levels.ERROR
      )
      return
    end
    M.set_adjust_factor(factor)
  end, {
    nargs = 1,
    desc = "Set golden ratio adjust factor",
  })
end

-- Enable golden ratio mode
function M.enable()
  if enabled then
    vim.notify("golden-ratio.nvim: Already enabled", vim.log.levels.INFO)
    return
  end

  enabled = true

  -- Create autocommand group
  autocmd_group = vim.api.nvim_create_augroup("GoldenRatio", { clear = true })

  -- Trigger on window enter
  vim.api.nvim_create_autocmd("WinEnter", {
    group = autocmd_group,
    callback = function()
      -- Use vim.schedule to avoid issues with window state
      vim.schedule(function()
        resize_window()
      end)
    end,
    desc = "Golden ratio resize on window enter",
  })

  -- Trigger on vim resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = autocmd_group,
    callback = function()
      vim.schedule(function()
        resize_window()
      end)
    end,
    desc = "Golden ratio resize on vim resize",
  })

  -- Trigger on buffer enter (for split creation)
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = autocmd_group,
    callback = function()
      vim.schedule(function()
        resize_window()
      end)
    end,
    desc = "Golden ratio resize on buffer window enter",
  })

  vim.notify("golden-ratio.nvim: Enabled", vim.log.levels.INFO)
  debug_log("Autocommands registered")

  -- Apply to current window (scheduled to avoid triggering autocmds in same frame)
  vim.schedule(function()
    resize_window()
  end)
end

-- Disable golden ratio mode
function M.disable()
  if not enabled then
    vim.notify("golden-ratio.nvim: Already disabled", vim.log.levels.INFO)
    return
  end

  enabled = false

  -- Clear autocommands
  if autocmd_group then
    vim.api.nvim_del_augroup_by_id(autocmd_group)
    autocmd_group = nil
  end

  -- Balance windows
  vim.cmd("wincmd =")

  vim.notify("golden-ratio.nvim: Disabled", vim.log.levels.INFO)
  debug_log("Autocommands cleared")
end

-- Toggle golden ratio mode
function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

-- Check if golden ratio is enabled
---@return boolean True if enabled
function M.is_enabled()
  return enabled
end

-- Manually trigger golden ratio resize
function M.resize()
  resize_window()
end

-- Toggle widescreen mode
function M.toggle_widescreen()
  local opts = config.get()
  if opts.adjust_factor == 1.0 then
    config.set("adjust_factor", opts.wide_adjust_factor)
    vim.notify(
      string.format("golden-ratio.nvim: Widescreen mode (factor: %.2f)", opts.wide_adjust_factor),
      vim.log.levels.INFO
    )
  else
    config.set("adjust_factor", 1.0)
    vim.notify("golden-ratio.nvim: Normal mode (factor: 1.0)", vim.log.levels.INFO)
  end
  resize_window()
end

-- Set adjustment factor
---@param factor number New adjustment factor
function M.set_adjust_factor(factor)
  config.set("adjust_factor", factor)
  vim.notify(
    string.format("golden-ratio.nvim: Adjust factor set to %.2f", factor),
    vim.log.levels.INFO
  )
  resize_window()
end

return M
