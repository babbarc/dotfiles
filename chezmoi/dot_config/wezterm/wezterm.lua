-- Entry point. Adapted from KevinSilvester/wezterm-config's wezterm.lua (MIT
-- License, Copyright (c) 2023 Kevin Silvester), commit
-- 052853ec9bbc4855026c3974a89ec34c826ba209: the wallpaper-backdrop init
-- (utils/backdrops.lua) is removed - see config/appearance.lua's
-- window_background_opacity comment for why - everything else is unchanged.
local Config = require('config')

require('events.left-status').setup()
require('events.right-status').setup({ date_format = '%a %H:%M:%S' })
require('events.tab-title').setup({
   hide_active_tab_unseen = true,
   unseen_icon = 'numbered_box',
   show_progress = true,
})
require('events.new-tab-button').setup()
require('events.gui-startup').setup()

return Config:init()
   :append(require('config.appearance'))
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options
