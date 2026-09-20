if status is-interactive
    # Commands to run in interactive sessions can go here
end


bind '，' 'commandline -i ","'

bind '。' 'commandline -i "."'

bind '！' 'commandline -i "!"'

bind '？' 'commandline -i "?"'

bind '；' 'commandline -i ";"'

bind '：' 'commandline -i ":"'

bind '（' 'commandline -i "("'

bind '）' 'commandline -i ")"'





if status is-interactive
    starship init fish | source
    zoxide init fish | source
end

# 用 global 而不是 universal，避免写入会被 Fish 原子替换的 fish_variables。
fish_add_path -g "$HOME/.atomecli/bin"
fish_add_path -g "$HOME/.local/bin"

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	command yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
		builtin cd -- "$cwd"
	end
	command rm -f -- "$tmp"
end
