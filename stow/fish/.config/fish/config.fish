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





starship init fish | source

# PATH
# 用 -g 而不是默认的 universal：universal 会写进 fish_variables，那个文件
# 不进仓库（fish 自己重写它，还容易混进密钥），配置得以 config.fish 为准。
fish_add_path -g "$HOME/.atomecli/bin"   # atomecli
fish_add_path -g "$HOME/.local/bin"      # uv

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	command yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
		builtin cd -- "$cwd"
	end
	command rm -f -- "$tmp"
end
