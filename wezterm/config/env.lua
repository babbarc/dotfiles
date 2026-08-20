-- Per-machine values from ~/.config/dotfiles/env (KEY=VALUE lines, '#' comments;
-- see env.example at the repo root). Lookup order: the env file, then the
-- process environment, then the caller-supplied default. The env file is
-- gitignored and per machine, and is read at runtime - so wezterm configs
-- never bake personal values into the repo or into the nix store.
local M = {}

local function read_env_file()
  local home = os.getenv('HOME') or os.getenv('USERPROFILE')
  if not home then
    return {}
  end
  local f = io.open(home .. '/.config/dotfiles/env', 'r')
  if not f then
    return {}
  end
  local env = {}
  for raw_line in f:lines() do
    local line = raw_line:gsub('^%s+', ''):gsub('%s+$', '')
    if line ~= '' and line:sub(1, 1) ~= '#' then
      local key, value = line:match('^([^=]+)=(.*)$')
      if key then
        env[key:gsub('^%s+', ''):gsub('%s+$', '')] = value
      end
    end
  end
  f:close()
  return env
end

local file_env = read_env_file()

--- Returns the value for `key`: the env file wins, then the process
--- environment, then `default`.
function M.get(key, default)
  if file_env[key] ~= nil then
    return file_env[key]
  end
  local v = os.getenv(key)
  if v ~= nil then
    return v
  end
  return default
end

return M
