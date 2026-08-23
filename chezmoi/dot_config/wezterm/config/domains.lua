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
         -- No default_prog: setting one makes wezterm invoke `wsl.exe --exec
         -- <prog>`, which does a raw execvpe() against a minimal PATH that
         -- doesn't include this NixOS-WSL host's fish (a system-profile
         -- symlink, not on a bare PATH). Omitting it lets wsl.exe use its
         -- normal default-entry launch, which correctly resolves the user's
         -- configured login shell (fish, set in
         -- nix/hosts/wsl/configuration.nix). Confirmed on the real machine:
         -- `wsl.exe --distribution NixOS --cd ... --user ... --exec fish -l`
         -- fails with execvpe ENOENT; the same command without --exec works.
      },
   }
end

return options
