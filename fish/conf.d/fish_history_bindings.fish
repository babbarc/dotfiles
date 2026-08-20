# Ctrl+R history search.
# Unlike bash/zsh, fish does NOT bind Ctrl+R by default (its native history
# search is the up-arrow). On a fresh install Ctrl+R does nothing, so bind it
# to history-search-backward explicitly.
#
# This repo's fish is set to vi key bindings (see fish_frozen_key_bindings.fish),
# so bind the key in the default mode (covers non-vi fish) AND in vi insert
# mode (the captain's actual typing mode). Binding a mode that isn't active
# (e.g. -M default/visual on a non-vi fish, or any -M when vi isn't loaded)
# is harmless, so the extra -M binds apply cleanly whether or not vi bindings
# are enabled.
bind \cr history-search-backward
bind -M insert \cr history-search-backward
bind -M default \cr history-search-backward
bind -M visual \cr history-search-backward
