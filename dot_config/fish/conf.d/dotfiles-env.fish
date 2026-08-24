# Load per-machine values from ~/.config/dotfiles/env (KEY=VALUE lines, '#'
# comments; see env.example at the repo root) into exported fish variables so
# fish functions (e.g. joy-console) see them. The file is gitignored and per
# machine; a missing file is fine - consumers fall back to their own defaults.
if test -f "$HOME/.config/dotfiles/env"
    while read -l line
        # skip blank lines and whole-line '#' comments
        if test -z "$line"; or string match -q -- '#*' "$line"
            continue
        end
        set -l parts (string split -m 1 -- '=' "$line")
        if test (count $parts) -eq 2
            set -gx $parts[1] $parts[2]
        end
    end <"$HOME/.config/dotfiles/env"
end
