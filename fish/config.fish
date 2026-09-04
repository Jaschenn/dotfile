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

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	command yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
		builtin cd -- "$cwd"
	end
	command rm -f -- "$tmp"
end
