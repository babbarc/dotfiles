local gpu_adapters = require('utils.gpu-adapter')
local backdrops = require('utils.backdrops')
local wezterm = require('wezterm')
-- local colors = require('colors.custom')

-- Dim unfocused windows so the focused one is obvious at a glance.
-- Adopted from kunchenguid/dotfiles wezterm.lua.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
   if actual == nil or expected == nil then
      return actual == expected
   end
   return actual.hue == expected.hue
      and actual.saturation == expected.saturation
      and actual.brightness == expected.brightness
end

wezterm.on('window-focus-changed', function(window)
   local overrides = window:get_config_overrides() or {}
   local text_hsb, opacity
   if not window:is_focused() then
      text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
      opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
   end

   -- Only write when one of the two values we own actually changes; a redundant
   -- set_config_overrides() call would trigger another config reload.
   if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
      return
   end

   overrides.foreground_text_hsb = text_hsb
   overrides.window_background_opacity = opacity
   window:set_config_overrides(overrides)
end)

return {
   max_fps = 120,
   front_end = 'WebGpu', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_best(),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Gl', 'Other'),
   underline_thickness = '1.5pt',

   -- cursor
   animation_fps = 120,
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'BlinkingBlock',
   cursor_blink_rate = 650,

   -- color scheme
   -- colors = colors,
   color_scheme = 'rose-pine-moon',

   -- background: pass in `true` if you want wezterm to start with focus mode on (no bg images)
   background = backdrops:initial_options({ no_img = false }),

   -- scrollbar
   enable_scroll_bar = false,

   -- tab bar
   enable_tab_bar = true,
   hide_tab_bar_if_only_one_tab = true,
   use_fancy_tab_bar = false,
   tab_max_width = 25,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette
   command_palette_fg_color = '#b4befe',
   command_palette_bg_color = '#11111b',
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window
   window_padding = {
      left = 0,
      right = 0,
      top = 0,
      bottom = 0,
   },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',
   window_background_opacity = 0.8,
   macos_window_background_blur = 50, -- macOS only; no-op on this Linux box
   window_decorations = 'RESIZE',
   window_frame = {
      active_titlebar_bg = '#090909',
      -- font = fonts.font,
      -- font_size = fonts.font_size,
   },
   -- inactive_pane_hsb = {
   --    saturation = 0.9,
   --    brightness = 0.65,
   -- },
   inactive_pane_hsb = {
      saturation = 1,
      brightness = 1,
   },

   visual_bell = {
      fade_in_function = 'EaseIn',
      fade_in_duration_ms = 250,
      fade_out_function = 'EaseOut',
      fade_out_duration_ms = 250,
      target = 'CursorColor',
   },
}
