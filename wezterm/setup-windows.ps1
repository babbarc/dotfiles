<#
.SYNOPSIS
One-click Windows wezterm setup for the dotfiles repo.

.DESCRIPTION
Lays down this repo's own complete, self-contained wezterm config (19 files:
wezterm.lua plus config/, utils/, events/ - fetched as raw files from the
public GitHub mirror) at %USERPROFILE%\.config\wezterm, and creates/updates
the per-machine env file at %USERPROFILE%\.config\dotfiles\env with exactly
the Windows-relevant keys.

This config has no dependency on the KevinSilvester/wezterm-config framework
- earlier versions of this script cloned that framework and overlaid 6 files
on top of it; this version migrates a machine that ran that older script by
removing the leftover framework clone (its .git directory, backdrops/,
colors/, and the utils/backdrops.lua + utils/gpu-adapter.lua files this
config no longer uses) before laying down the 19 files.

Idempotent: re-running keeps existing env values as the prompt defaults and
only rewrites what changed. Pass -WhatIf to preview every step without
changing anything.

Requires PowerShell 5.1 or later and network access (no git needed - this
script only downloads files over HTTPS). ASCII-only on purpose (no encoding
surprises on any Windows codepage).

.NOTES
Mirrors what nix/setup.sh does per role, but for the Windows machine: this
repo's public mirror is the source of the config, so no dotfiles checkout is
needed on the Windows box. JOY_CONSOLE_*/STEREO_* keys are not needed on
Windows and are never written.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------

function Write-Info { param([string]$Message) Write-Host $Message }
function Write-Step { param([string]$Message) Write-Host ''; Write-Host ('>> ' + $Message) -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Host ('WARNING: ' + $Message) -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host ('ERROR: ' + $Message) -ForegroundColor Red; Write-Host 'Fix the problem and re-run the script - nothing was changed in this step.'; exit 1 }

function Write-Banner {
   Write-Host ''
   Write-Host '============================================================'
   Write-Host '  dotfiles - one-click Windows wezterm setup'
   Write-Host '============================================================'
   Write-Host ''
   Write-Host '  Lays down this repo''s own wezterm config at'
   Write-Host '    %USERPROFILE%\.config\wezterm'
   Write-Host '  (no external framework dependency), plus the per-machine'
   Write-Host '  env file at'
   Write-Host '    %USERPROFILE%\.config\dotfiles\env'
   Write-Host ''
   Write-Host '  Re-run any time to update. No personal values are hardcoded'
   Write-Host '  in this script - the env file holds yours.'
   Write-Host '============================================================'
   Write-Host ''
}

function Read-EnvFile {
   # Parses KEY=VALUE lines into a hashtable (later lines win). Mirrors the
   # parsing in wezterm/config/env.lua: whole-line '#' comments and blank
   # lines are skipped, the key is trimmed, the value is taken verbatim.
   param([string]$Path)
   $defs = @{}
   if (Test-Path -LiteralPath $Path) {
      foreach ($raw in Get-Content -LiteralPath $Path) {
         $line = $raw.Trim()
         if ($line -eq '' -or $line.StartsWith('#')) { continue }
         $eq = $line.IndexOf('=')
         if ($eq -gt 0) {
            $defs[$line.Substring(0, $eq).Trim()] = $line.Substring($eq + 1)
         }
      }
   }
   return $defs
}

function Read-Value {
   # Prompts for a value. Enter keeps the [default]; a typed value wins;
   # 'skip' or '-' (only with -AllowSkip) returns '' so the key is omitted.
   # -Required re-prompts until a non-empty value is given.
   param(
      [string]$Prompt,
      [string]$Default = '',
      [switch]$AllowSkip,
      [switch]$Required
   )
   while ($true) {
      if ($AllowSkip) {
         if ($Default -ne '') {
            Write-Host -NoNewline ($Prompt + ' [' + $Default + "] (Enter keeps, 'skip' omits): ")
         } else {
            Write-Host -NoNewline ($Prompt + " ('skip' to omit): ")
         }
      } else {
         Write-Host -NoNewline ($Prompt + ' [' + $Default + ']: ')
      }
      $answer = Read-Host
      if ($AllowSkip -and ($answer -eq 'skip' -or $answer -eq '-')) { return '' }
      if ($answer.Trim() -ne '') { return $answer.Trim() }
      if ($Default -ne '') { return $Default }
      if (-not $Required) { return '' }
      Write-Warn 'that cannot be empty - please type a value'
   }
}

function Get-EnvValues {
   # Prompts for the 10 Windows-relevant keys. Values from an existing env
   # file become the defaults, so a re-run keeps the machine's setup. The WSL
   # users default to the Windows username; the cwd values derive from them.
   param([hashtable]$Defs, [string]$WinUser)

   $Values = @{}
   Write-Info 'Enter keeps a [default]. Server values are optional: Enter with'
   Write-Info "no default (or 'skip') omits them - each omission prints a warning."
   Write-Info ''

   $def = if ($Defs['DOTFILES_SERVER_HOST']) { $Defs['DOTFILES_SERVER_HOST'] } else { '' }
   $Values['DOTFILES_SERVER_HOST'] = Read-Value 'Home server hostname or ssh alias (optional)' $def -AllowSkip
   if (-not $Values['DOTFILES_SERVER_HOST']) {
      Write-Warn 'DOTFILES_SERVER_HOST omitted - the wezterm ssh-to-server domain and its keybinding will not be added'
   }

   $def = if ($Defs['DOTFILES_SERVER_USER']) { $Defs['DOTFILES_SERVER_USER'] } else { '' }
   $Values['DOTFILES_SERVER_USER'] = Read-Value 'Username to ssh into the server as (optional)' $def -AllowSkip
   if (-not $Values['DOTFILES_SERVER_USER']) {
      Write-Warn 'DOTFILES_SERVER_USER omitted - ssh-to-server integrations will not know which user to use'
   }

   Write-Info ''
   $def = if ($Defs['WEZTERM_SSH_WSL_USER']) { $Defs['WEZTERM_SSH_WSL_USER'] } else { $WinUser }
   $Values['WEZTERM_SSH_WSL_USER'] = Read-Value 'WSL user for the ssh:wsl domain (ssh from Windows into the distro)' $def -Required

   $def = if ($Defs['WEZTERM_WSL_DISTRO']) { $Defs['WEZTERM_WSL_DISTRO'] } else { 'NixOS' }
   $Values['WEZTERM_WSL_DISTRO'] = Read-Value 'WSL distro name' $def -Required

   $def = if ($Defs['WEZTERM_WSL_FISH_USER']) { $Defs['WEZTERM_WSL_FISH_USER'] } else { $WinUser }
   $Values['WEZTERM_WSL_FISH_USER'] = Read-Value 'WSL user for the wsl:ubuntu-fish domain (fish login)' $def -Required

   $def = if ($Defs['WEZTERM_WSL_FISH_CWD']) { $Defs['WEZTERM_WSL_FISH_CWD'] } else { '/home/' + $Values['WEZTERM_WSL_FISH_USER'] }
   $Values['WEZTERM_WSL_FISH_CWD'] = Read-Value 'WSL working directory for the fish domain' $def -Required

   $def = if ($Defs['WEZTERM_WSL_BASH_USER']) { $Defs['WEZTERM_WSL_BASH_USER'] } else { $WinUser }
   $Values['WEZTERM_WSL_BASH_USER'] = Read-Value 'WSL user for the wsl:ubuntu-bash domain (bash login)' $def -Required

   $def = if ($Defs['WEZTERM_WSL_BASH_CWD']) { $Defs['WEZTERM_WSL_BASH_CWD'] } else { '/home/' + $Values['WEZTERM_WSL_BASH_USER'] }
   $Values['WEZTERM_WSL_BASH_CWD'] = Read-Value 'WSL working directory for the bash domain' $def -Required

   $def = if ($Defs['WEZTERM_WSL_SYSTEM_USER']) { $Defs['WEZTERM_WSL_SYSTEM_USER'] } else { $WinUser }
   $Values['WEZTERM_WSL_SYSTEM_USER'] = Read-Value 'WSL system user (the NixOS-WSL host user)' $def -Required

   $def = if ($Defs['WEZTERM_GIT_BASH_PATH']) { $Defs['WEZTERM_GIT_BASH_PATH'] } else { 'C:\Program Files\Git\bin\bash.exe' }
   $Values['WEZTERM_GIT_BASH_PATH'] = Read-Value 'Full path to Git Bash bash.exe (launch menu entry)' $def -Required

   return $Values
}

function Write-EnvFile {
   # Writes the env file deterministically: exactly the Windows-relevant keys,
   # in a fixed order, no BOM. Keys whose value is empty stay out of the file.
   param([hashtable]$Values, [string]$Path)

   $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
   $lines = New-Object System.Collections.Generic.List[string]
   $lines.Add('# Generated by wezterm/setup-windows.ps1 on ' + $now + ' - re-run the script to regenerate.')
   $lines.Add('# Per-machine values for the dotfiles repo (Windows wezterm host). See env.example')
   $lines.Add('# in the repo for documentation of every key. Plaintext and gitignored - keep')
   $lines.Add('# secrets OUT of this file; credentials stay in the OS secret store / pass.')
   $lines.Add('#')
   $lines.Add('# Written deterministically: only the Windows-relevant keys, in this order.')
   $lines.Add('# Existing keys outside this set are dropped on rewrite; a re-run keeps the')
   $lines.Add('# values you type (they become the next run''s prompt defaults).')

   $lines.Add('')
   $lines.Add('# server (wezterm ssh domain)')
   if ($Values['DOTFILES_SERVER_HOST']) { $lines.Add('DOTFILES_SERVER_HOST=' + $Values['DOTFILES_SERVER_HOST']) }
   if ($Values['DOTFILES_SERVER_USER']) { $lines.Add('DOTFILES_SERVER_USER=' + $Values['DOTFILES_SERVER_USER']) }

   $lines.Add('')
   $lines.Add('# wezterm / WSL')
   if ($Values['WEZTERM_SSH_WSL_USER']) { $lines.Add('WEZTERM_SSH_WSL_USER=' + $Values['WEZTERM_SSH_WSL_USER']) }
   if ($Values['WEZTERM_WSL_DISTRO']) { $lines.Add('WEZTERM_WSL_DISTRO=' + $Values['WEZTERM_WSL_DISTRO']) }
   if ($Values['WEZTERM_WSL_FISH_USER']) { $lines.Add('WEZTERM_WSL_FISH_USER=' + $Values['WEZTERM_WSL_FISH_USER']) }
   if ($Values['WEZTERM_WSL_FISH_CWD']) { $lines.Add('WEZTERM_WSL_FISH_CWD=' + $Values['WEZTERM_WSL_FISH_CWD']) }
   if ($Values['WEZTERM_WSL_BASH_USER']) { $lines.Add('WEZTERM_WSL_BASH_USER=' + $Values['WEZTERM_WSL_BASH_USER']) }
   if ($Values['WEZTERM_WSL_BASH_CWD']) { $lines.Add('WEZTERM_WSL_BASH_CWD=' + $Values['WEZTERM_WSL_BASH_CWD']) }
   if ($Values['WEZTERM_WSL_SYSTEM_USER']) { $lines.Add('WEZTERM_WSL_SYSTEM_USER=' + $Values['WEZTERM_WSL_SYSTEM_USER']) }

   $lines.Add('')
   $lines.Add('# wezterm / launch menu')
   if ($Values['WEZTERM_GIT_BASH_PATH']) { $lines.Add('WEZTERM_GIT_BASH_PATH=' + $Values['WEZTERM_GIT_BASH_PATH']) }

   $content = ($lines -join "`r`n") + "`r`n"
   $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
   [System.IO.File]::WriteAllText($Path, $content, $utf8NoBom)
}

# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------

Write-Banner

# --- paths -------------------------------------------------------------------

$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
if (-not $HomeDir) { Write-Fail 'could not determine your home directory (set the USERPROFILE environment variable)' }

$ConfigRoot = Join-Path $HomeDir '.config'
$WeztermDir = Join-Path $ConfigRoot 'wezterm'
$ConfigDir  = Join-Path $WeztermDir 'config'
$EnvDir     = Join-Path $ConfigRoot 'dotfiles'
$EnvFile    = Join-Path $EnvDir 'env'

$ConfigBase = 'https://raw.githubusercontent.com/babbarc/dotfiles/master/wezterm/'
# Every file this config's wezterm.lua transitively require()s, relative to
# $ConfigBase / $WeztermDir. Keep in sync with the wezterm/ tree in the repo -
# there is no directory listing to fetch from a raw.githubusercontent.com URL,
# so the file list has to be named explicitly.
$ConfigFiles = @(
   'wezterm.lua',
   'config/appearance.lua',
   'config/bindings.lua',
   'config/domains.lua',
   'config/env.lua',
   'config/fonts.lua',
   'config/general.lua',
   'config/init.lua',
   'config/launch.lua',
   'utils/cells.lua',
   'utils/math.lua',
   'utils/opts-validator.lua',
   'utils/platform.lua',
   'utils/str.lua',
   'events/gui-startup.lua',
   'events/left-status.lua',
   'events/new-tab-button.lua',
   'events/right-status.lua',
   'events/tab-title.lua'
)
# Leftovers from the old KevinSilvester/wezterm-config framework clone that
# this config no longer uses (see migration cleanup below).
$StaleFrameworkPaths = @('.git', 'backdrops', 'colors', 'utils\backdrops.lua', 'utils\gpu-adapter.lua')
$EnvKeys = @(
   'DOTFILES_SERVER_HOST',
   'DOTFILES_SERVER_USER',
   'WEZTERM_SSH_WSL_USER',
   'WEZTERM_WSL_DISTRO',
   'WEZTERM_WSL_FISH_USER',
   'WEZTERM_WSL_FISH_CWD',
   'WEZTERM_WSL_BASH_USER',
   'WEZTERM_WSL_BASH_CWD',
   'WEZTERM_WSL_SYSTEM_USER',
   'WEZTERM_GIT_BASH_PATH'
)

if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
   Write-Warn 'this looks like PowerShell on Linux/macOS - this script targets Windows'
   Write-Warn '(it configures %USERPROFILE%\.config\wezterm). If you are inside WSL, run it in Windows PowerShell instead.'
}

# --- prerequisites ------------------------------------------------------------

Write-Step 'Checking prerequisites'
Write-Info ('  home dir: ' + $HomeDir)
Write-Info '  (no git required - this script only downloads files over HTTPS)'

# --- migration: remove a leftover KevinSilvester/wezterm-config clone --------

$StaleFound = @($StaleFrameworkPaths | Where-Object { Test-Path -LiteralPath (Join-Path $WeztermDir $_) })
if ($StaleFound.Count -gt 0) {
   Write-Step 'Removing leftover wezterm-config framework files'
   Write-Info '  an earlier version of this script cloned KevinSilvester/wezterm-config;'
   Write-Info '  this config does not use it any more, so these are being removed:'
   foreach ($rel in $StaleFound) {
      $full = Join-Path $WeztermDir $rel
      if ($PSCmdlet.ShouldProcess($full, 'remove leftover framework path')) {
         Remove-Item -LiteralPath $full -Recurse -Force
         Write-Info ('  removed ' + $rel)
      }
   }
}

# --- config files ---------------------------------------------------------------

Write-Step 'Writing the wezterm config'
if (-not $WhatIfPreference) {
   New-Item -ItemType Directory -Force -Path $ConfigRoot | Out-Null
   New-Item -ItemType Directory -Force -Path $WeztermDir | Out-Null
   New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
   New-Item -ItemType Directory -Force -Path (Join-Path $WeztermDir 'utils') | Out-Null
   New-Item -ItemType Directory -Force -Path (Join-Path $WeztermDir 'events') | Out-Null
}

foreach ($f in $ConfigFiles) {
   $dest = Join-Path $WeztermDir ($f -replace '/', [IO.Path]::DirectorySeparatorChar)
   $url = $ConfigBase + $f
   if ($PSCmdlet.ShouldProcess($dest, 'download ' + $f + ' from ' + $url)) {
      try {
         Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $dest
         if ((Get-Item -LiteralPath $dest).Length -eq 0) { throw 'downloaded file is empty' }
         $firstLine = (Get-Content -LiteralPath $dest -TotalCount 1).Trim()
         if (-not ($firstLine -like 'local*' -or $firstLine -like '--*')) {
            throw ('downloaded file does not look like a lua config (first line: ' + $firstLine + ')')
         }
         Write-Info ('  ' + $f)
      } catch {
         Write-Fail ('failed to download ' + $f + ' from ' + $url + ' - ' + $_.Exception.Message)
      }
   }
}

# --- per-machine env file ------------------------------------------------------

Write-Step 'Per-machine env file'
$Defs = Read-EnvFile $EnvFile
if ($Defs.Count -gt 0) {
   Write-Info ('  existing env file found at ' + $EnvFile + ' - its values are the defaults below')
} else {
   Write-Info ('  no existing env file at ' + $EnvFile + ' - creating one')
}

# Keys outside the Windows set are dropped on rewrite, so the file stays
# deterministic (the nix/setup.sh per-role writer does the same).
$Dropped = @()
foreach ($key in $Defs.Keys) {
   if ($EnvKeys -notcontains $key) { $Dropped += $key }
}

$WinUser = $env:USERNAME
if (-not $WinUser) { $WinUser = 'user' }

if ($WhatIfPreference) {
   Write-Info '  (-WhatIf) interactive prompts are skipped in dry-run mode; a real run'
   Write-Info ('  prompts for the 10 Windows keys and writes ' + $EnvFile)
} else {
   $Values = Get-EnvValues -Defs $Defs -WinUser $WinUser
   if ($PSCmdlet.ShouldProcess($EnvFile, 'write the per-machine env file')) {
      New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
      Write-EnvFile -Values $Values -Path $EnvFile
      Write-Info ('  wrote ' + $EnvFile)
      if ($Dropped.Count -gt 0) {
         Write-Warn ('dropped keys outside the Windows set (removed from the file): ' + ($Dropped -join ', '))
      }
   }
}

# --- summary ------------------------------------------------------------------

Write-Step 'Done'
Write-Host ''
Write-Host ('  wezterm config : ' + $WeztermDir + '   (' + $ConfigFiles.Count + ' files, no external framework)')
Write-Host ('  per-machine env : ' + $EnvFile)
Write-Host ''
Write-Host '  Restart wezterm (close all its windows) to load the new config.'
Write-Host '  Re-run this script any time to update - it re-downloads all'
Write-Host '  files above. The env file is plaintext and machine-specific -'
Write-Host '  keep it out of version control and keep secrets out of it.'
Write-Host ''
if ($WhatIfPreference) {
   Write-Warn 'dry-run (-WhatIf): nothing was changed - re-run without -WhatIf to apply'
}
