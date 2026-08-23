function joy-console --description 'open an interactive shell in the JOY_CONSOLE_CONTAINER container on the dotfiles server (see ~/.config/dotfiles/env)'
    # Per-machine values from ~/.config/dotfiles/env, loaded by
    # fish/conf.d/dotfiles-env.fish.
    if not set -q DOTFILES_SERVER_HOST
        or not set -q JOY_CONSOLE_CONTAINER_USER
        or not set -q JOY_CONSOLE_CONTAINER
        or not set -q JOY_CONSOLE_CONTAINER_HOME
        echo "joy-console: set DOTFILES_SERVER_HOST, JOY_CONSOLE_CONTAINER_USER, JOY_CONSOLE_CONTAINER" >&2
        echo "             and JOY_CONSOLE_CONTAINER_HOME in ~/.config/dotfiles/env (see env.example)" >&2
        return 1
    end

    set -l remote 'cd /tmp && sudo -u '$JOY_CONSOLE_CONTAINER_USER' podman exec -it -u '$JOY_CONSOLE_CONTAINER_USER' '$JOY_CONSOLE_CONTAINER' /bin/bash -c "export HOME='$JOY_CONSOLE_CONTAINER_HOME' && source ~/.bashrc && '$JOY_CONSOLE_CONTAINER'"'
    ssh -t $DOTFILES_SERVER_HOST $remote $argv
end
