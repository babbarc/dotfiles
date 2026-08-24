function rgf
    rg --line-number --no-heading --color=always $argv | fzf --ansi \
        --delimiter : \
        --preview 'bat --style=numbers --color=always {1} --highlight-line {2}' \
        --bind 'enter:execute(vim {1} +{2})'
end
