local platform = require('utils.platform')
local env = require('config.env')

---@type Config
local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   options.default_prog = { 'pwsh', '-NoLogo' }
   options.launch_menu = {
      { label = 'PowerShell Core', args = { 'pwsh', '-NoLogo' } },
      { label = 'PowerShell Desktop', args = { 'powershell' } },
      { label = 'Command Prompt', args = { 'cmd' } },
      { label = 'Nushell', args = { 'nu' } },
      { label = 'Msys2', args = { 'ucrt64.cmd' } },
      {
         label = 'Git Bash',
         args = { env.get('WEZTERM_GIT_BASH_PATH', 'C:\\Program Files\\Git\\bin\\bash.exe') },
      },
   }
elseif platform.is_mac then
   options.default_prog = { os.getenv('SHELL') or 'fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Nushell', args = { 'nu', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'fish' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash' } },
      { label = 'Fish', args = { 'fish' } },
      { label = 'Zsh', args = { 'zsh' } },
   }
end

return options
