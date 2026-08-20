local platform = require('utils.platform')
local env = require('config.env')

---@type Config
local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   -- ssh_domains = {},
   ssh_domains = {},

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},
}

-- ssh to the home server (yazi's image preview on Windows will only work if
-- launched via ssh from WSL). Values come from the per-machine env file
-- (DOTFILES_SERVER_HOST / DOTFILES_SERVER_USER, see env.example); the domain
-- is only added when the env file names a server.
local server_host = env.get('DOTFILES_SERVER_HOST')
if server_host and server_host ~= '' then
   options.ssh_domains = {
      {
         name = env.get('DOTFILES_SERVER_USER', 'server'),
         remote_address = server_host,
      },
   }
end

if platform.is_win then
   options.ssh_domains = {
      {
         name = 'ssh:wsl',
         username = env.get('WEZTERM_SSH_WSL_USER', 'user'),
         remote_address = 'localhost',
         multiplexing = 'None',
         default_prog = { 'fish', '-l' },
         assume_shell = 'Posix',
      },
   }

   options.wsl_domains = {
      -- old Ubuntu WSL distro - fish login
      {
         name = 'wsl:ubuntu-fish',
         distribution = env.get('WEZTERM_WSL_DISTRO', 'Ubuntu'),
         username = env.get('WEZTERM_WSL_FISH_USER', 'user'),
         default_cwd = env.get('WEZTERM_WSL_FISH_CWD', '/home/user'),
         default_prog = { 'fish', '-l' },
      },
      -- old Ubuntu WSL distro - bash login
      {
         name = 'wsl:ubuntu-bash',
         distribution = env.get('WEZTERM_WSL_DISTRO', 'Ubuntu'),
         username = env.get('WEZTERM_WSL_BASH_USER', 'user'),
         default_cwd = env.get('WEZTERM_WSL_BASH_CWD', '/home/user'),
         default_prog = { 'bash', '-l' },
      },
   }
end

return options
