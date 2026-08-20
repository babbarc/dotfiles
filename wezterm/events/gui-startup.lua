-- Vendored from KevinSilvester/wezterm-config (MIT License, Copyright (c) 2023
-- Kevin Silvester), commit 052853ec9bbc4855026c3974a89ec34c826ba209.
-- Unmodified.

local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _, _, window = mux.spawn_window(cmd or {})
      window:gui_window():maximize()
   end)
end

return M
