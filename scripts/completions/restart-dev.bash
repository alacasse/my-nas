#!/bin/bash

# scripts/completions/restart-dev.bash
# Source this file to enable autocompletion for ./scripts/restart-dev.sh

_restart_dev_completions()
{
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Suggest directories in apps/ as they likely correspond to services
    # We use 'ls -1 apps/' and filter standard entries to be fast (no cluster calls)
    local services
    services=$(ls -1 apps/ 2>/dev/null | grep -vE "^(base)$")

    COMPREPLY=($(compgen -W "${services}" -- ${cur}))
}

complete -F _restart_dev_completions ./scripts/restart-dev.sh
complete -F _restart_dev_completions scripts/restart-dev.sh
