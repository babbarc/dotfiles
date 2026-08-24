-- Vendored from KevinSilvester/wezterm-config (MIT License, Copyright (c) 2023
-- Kevin Silvester), commit 052853ec9bbc4855026c3974a89ec34c826ba209.
-- Unmodified.

local M = {}

---@param str string
---@param prefix string
---@return boolean
M.starts_with = function(str, prefix)
   return str:sub(1, #prefix) == prefix
end

---@param str string
---@param suffix string
---@return boolean
M.ends_with = function(str, suffix)
   return str:sub(-#suffix) == suffix
end

return M
