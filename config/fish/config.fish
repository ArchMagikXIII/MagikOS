# Magikos fish config. Self-contained: no distro fish frameworks, and the
# oh-my-posh prompt degrades gracefully when the binary is not installed.

set -gx PATH "$HOME/.local/bin" $PATH

if status is-interactive
    # Prompt: oh-my-posh with the vendored Night Owl theme
    if type -q oh-my-posh
        oh-my-posh init fish --config ~/.config/fish/night-owl.omp.json | source
    end

    # System summary with the Magikos ASCII art, matching the bash greeting
    if test -r ~/.config/fastfetch/MagikOS.txt; and type -q fastfetch
        fastfetch
    end
end
