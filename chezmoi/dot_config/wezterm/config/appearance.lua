local wezterm = require('wezterm')

-- Dim unfocused windows so the focused one is obvious at a glance. Only the
-- foreground text is dimmed (a pure glyph-color transform) - deliberately NOT
-- window_background_opacity, see the window_background_opacity comment below
-- for why opacity is never touched by this config at all.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }

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
   local text_hsb = nil
   if not window:is_focused() then
      text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
   end

   -- Only write when the value we own actually changes; a redundant
   -- set_config_overrides() call would trigger another config reload.
   if same_text_hsb(overrides.foreground_text_hsb, text_hsb) then
      return
   end

   overrides.foreground_text_hsb = text_hsb
   window:set_config_overrides(overrides)
end)

return {
   max_fps = 120,

   -- front_end: OpenGL, not WebGpu. WebGpu is where the "colour spilling"
   -- symptom lived: wezterm's WebGpu backend has a long, still-open history of
   -- getting background-opacity/backdrop-image compositing wrong in exactly
   -- this feature combination (wezterm/wezterm#3773, #6359, #4502, #3032 -
   -- ranging May 2023 to Nov 2024, i.e. spanning versions both older and
   -- newer than the 20240203 build this repo runs). OpenGL is the documented,
   -- reliable workaround cited in several of those issues. Since this config
   -- no longer uses background-image layers or opacity <1 at all (see
   -- window_background_opacity below), the specific bug class those issues
   -- describe cannot recur even if WebGpu regresses further - but OpenGL is
   -- also just the more mature, less surprising backend for a 2D terminal
   -- workload, so there's no reason to accept WebGpu's risk for it.
   front_end = 'OpenGL', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   underline_thickness = '1.5pt',

   -- cursor
   animation_fps = 120,
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'BlinkingBlock',
   cursor_blink_rate = 650,

   -- color scheme
   color_scheme = 'rose-pine-moon',

   -- scrollbar
   enable_scroll_bar = false,

   -- tab bar
   enable_tab_bar = true,
   hide_tab_bar_if_only_one_tab = true,
   use_fancy_tab_bar = false,
   tab_max_width = 25,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette (retimed to rose-pine-moon: iris on surface, was
   -- catppuccin-mocha lavender-on-crust left over from the upstream framework)
   command_palette_fg_color = '#c4a7e7',
   command_palette_bg_color = '#2a273f',
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window: the "floating panel" look
   --
   -- WezTerm does not draw its own rounded window corners on any platform -
   -- that's confirmed against wezterm/wezterm#2430 (open feature request,
   -- never implemented) and discussion #2751 (maintainer: rounding is "a
   -- feature of the desktop environment / compositor", not wezterm's job).
   -- Corner rounding is always delegated to whatever draws the window frame:
   --   - Windows 11: DWM auto-rounds *standard* decorated top-level windows.
   --     window_decorations = 'RESIZE' (below) makes wezterm paint its own
   --     custom borderless-style frame instead of a standard caption, which
   --     is the documented pattern for losing DWM's automatic rounding
   --     (Microsoft's own "apply rounded corners" guidance calls out
   --     non-standard-chrome windows as needing an explicit opt-in via
   --     DwmSetWindowAttribute/DWM_WINDOW_CORNER_PREFERENCE - wezterm does
   --     not call that API). To get real native rounding back on Windows,
   --     change window_decorations to 'TITLE | RESIZE' - at the cost of a
   --     visible title bar. NOT applied here by default, to keep the look
   --     identical on both hosts rather than silently forking it; this is
   --     named so the captain can flip it in one line if they'd rather have
   --     genuine rounding than the chrome-free look on the Windows box.
   --   - Linux/Sway (this repo's laptop, see sway/config): plain Sway/wlroots
   --     has NO corner-radius concept at all - that capability only exists in
   --     the SwayFX fork (github.com/wlrfx/swayfx), which replaces wlroots'
   --     renderer to add corner_radius/blur/shadow. Getting real rounding on
   --     the laptop would mean swapping compositors system-wide, which is a
   --     bigger, riskier, separate decision outside wezterm/'s scope (and
   --     outside this task) - named here rather than silently dropped, not
   --     implemented.
   -- So on both hosts, "rounded floating window" is approximated here as a
   -- floating PANEL: real padding as breathing room (was 0 - directly
   -- contributed to the "sharp corners" feel by running content flush to the
   -- window edge with no OS frame to soften it) plus a fully opaque,
   -- theme-matched background. A bigger visual win than padding alone -
   -- named, not applied - would be Sway's built-in `gaps inner`/`gaps outer`
   -- in sway/config: real spacing between tiled windows, no compositor swap
   -- needed, unlike corner_radius. Out of scope for this wezterm-only patch.
   window_padding = {
      left = 12,
      right = 12,
      top = 12,
      bottom = 12,
   },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',

   -- window_background_opacity: intentionally left unset (defaults to 1.0,
   -- fully opaque). This is the primary fix for "colour spilling over".
   --
   -- Root cause: the upstream framework's backdrops module (utils/backdrops.lua,
   -- no longer part of this config) always painted an oversized (120% size, -10%
   -- offset) fallback color layer *behind* the wallpaper image, using a
   -- hardcoded catppuccin-mocha hex (colors/custom.lua's mocha.base,
   -- #1f1f28) that never tracked whatever color_scheme this file actually
   -- set (rose-pine-moon, background #232136 - a visibly different hue).
   -- Whenever the wallpaper image didn't exactly fill the window (resize,
   -- aspect-ratio mismatch, backdrop-cycling keybindings), that mismatched
   -- color showed through as an incongruous band right at the window edge -
   -- directly touching the edge because window_padding was 0 and
   -- window_decorations left no OS frame to mask it. window_background_opacity
   -- = 0.8 (0.62 unfocused) then alpha-blended that mismatched layer with
   -- the desktop behind the window, and front_end = 'WebGpu' had its own
   -- documented compositing bugs for this exact opacity+backdrop combination
   -- (see front_end comment above) that made the effect inconsistent across
   -- GPU/driver combos - i.e. "still feels buggy".
   --
   -- Rather than re-theme the fallback color and hope no future mismatch
   -- reappears, this config drops the wallpaper/backdrop system entirely:
   -- no image layers, no opacity, no alpha compositing of any kind, so the
   -- whole bug class is structurally impossible, not just patched. The
   -- tradeoff is losing the wallpaper-cycling feature (SUPER+/, SUPER+,/.,
   -- SUPER+b in the old bindings.lua) - a real loss if the captain liked it,
   -- but it was never part of the reported complaint, and it's easy to bring
   -- back later (re-vendor utils/backdrops.lua, fix its hardcoded color to
   -- track color_scheme, and only re-enable opacity if front_end is kept on
   -- OpenGL, which does not share WebGpu's documented opacity bugs).
   window_decorations = 'RESIZE',
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
