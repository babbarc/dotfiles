local platform = require('utils.platform')
local env = require('config.env')

---@type Config
local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   -- Not used: this repo doesn't ssh into any host from wezterm.
   ssh_domains = {},

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},
}

if platform.is_win then
   options.wsl_domains = {
      {
         name = 'wsl:nixos',
         -- This repo's nix/hosts/wsl/configuration.nix sets no custom WSL
         -- distro/hostname, so this is NixOS-WSL's default registration name.
         -- If `wsl -l` on the actual machine shows something else, fix this.
         distribution = 'NixOS',
         username = env.get('WEZTERM_WSL_SYSTEM_USER', 'user'),
         default_cwd = '/home/' .. env.get('WEZTERM_WSL_SYSTEM_USER', 'user'),
         -- nix/hosts/wsl/configuration.nix sets the user's shell to fish.
         default_prog = { 'fish', '-l' },
      },
   }
end

return options
