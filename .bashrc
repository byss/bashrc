#!/bin/bash

# Localization
export LANG='en_US.UTF-8'
export LC_COLLATE='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_MESSAGES='en_US.UTF-8'
export LC_MONETARY='en_US.UTF-8'
export LC_NUMERIC='en_US.UTF-8'
export LC_TIME='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# Text effects
export NORMAL='\e[0m'
export BOLD='\e[1m'
export UNDERLINE='\e[4m'
export BLINK='\e[5m'
export NEGATIVE='\e[7m'

# Text colors
export BLACK_COLOR='\e[30m'
export RED_COLOR='\e[31m'
export GREEN_COLOR='\e[32m'
export YELLOW_COLOR='\e[33m'
export BLUE_COLOR='\e[34m'
export MAGENTA_COLOR='\e[35m'
export CYAN_COLOR='\e[36m'
export WHITE_COLOR='\e[37m'

# Background colors
export BLACK_BG_COLOR='\e[40m'
export RED_BG_COLOR='\e[41m'
export GREEN_BG_COLOR='\e[42m'
export YELLOW_BG_COLOR='\e[43m'
export BLUE_BG_COLOR='\e[44m'
export MAGENTA_BG_COLOR='\e[45m'
export CYAN_BG_COLOR='\e[46m'
export WHITE_BG_COLOR='\e[47m'

# Prompt
export PS1='\['"${NORMAL}${GREEN_COLOR}"'\]\u\['"${NORMAL}"'\]@\H:\['"${BOLD}${RED_COLOR}"'\]\w\['"${NORMAL}"'\] \['"${BOLD}${BLUE_COLOR}"'\][\t]\$ \['"${NORMAL}"'\]'
export PS2='	> '

# Editor
export EDITOR='/usr/bin/nano'

# Python startup
export PYTHONSTARTUP="${HOME}/.pythonrc.py"

# Laaaaaaaarge history
export HISTFILESIZE=1048576
export HISTSIZE=1048576

# History tuning
export HISTCONTROL="ignoredups"

# Shell options
shopt -s autocd # ./dir <=> cd dir
shopt -s cdspell # autocorrection
shopt -s checkwinsize # always have actual $LINES & $COLUMNS
shopt -u cmdhist # use semicolon instead of newline
shopt -u direxpand # do not expand tilde and so on
shopt -s dotglob # echo * sees dotfiles
shopt -s extdebug # MOAR debugging
shopt -s globstar # '**' support
shopt -u gnu_errfmt # POSIX, not GNU error messages
shopt -s histappend # Appends history to $HISTFILE instead of overwriting
shopt -s huponexit # kill all bg jobs on exit
shopt -u lithist # use semicolons instead of newlines in history
shopt -s no_empty_cmd_completion # empty command completion is stupid
shopt -u nocaseglob # filenames ARE case-sensitive
shopt -u nocasematch # comparisons ARE case-sensitive
shopt -s xpg_echo # echo has '-e' by default

# Reloads bash environment
r() {
	. "${BASH_SOURCE}"
}

# Updates terminal title
update_title() {
	echo -e '\e];' "$@" '\a'
}

# Adds path to $PATH, uiniqueness is guarantied
expand_path() {
	local old_ifs="${IFS}"
	local new_path="${PATH}"
	
	IFS=':'
	new_dirs=( "$@" )
	for dirs_string in "${new_dirs[@]}"; do
		read -a dirs_list <<< "${dirs_string}"
		for d in "${dirs_list[@]}"; do
			if [[ "${new_path}" != *"${d}"* ]]; then
				new_path="${d}:${new_path}"
			fi
		done
	done
	export PATH="${new_path}"
	IFS="${old_ifs}"
}

# Path
expand_path "/opt/local/libexec/gnubin" # GNU Coreutils from MacPorts
expand_path "~/local/bin" # some stuff
expand_path "~/adt-bundle-mac-x86_64/sdk/tools:~/adt-bundle-mac-x86_64/sdk/platform-tools" # Android SDK

# Thick black horizontal line
hr() {
	local cols=$((COLUMNS + 0)) # cols to int
	
	echo -ne "${BLACK_COLOR}${BLACK_BG_COLOR}"
	if [ ${cols} -gt 0 ]; then
		python -c 'print " " * '$((cols))
	else
		echo -ne '\x1b\n'
	fi
	
	echo -ne "${NORMAL}"
}

# Alias template
alias_func_template() {
	local orig_binary="$(which ${cmd})"
	echo 'OLDPATH="${PATH}"'
	echo 'unset PATH'
	echo "${cmd}"'() {'
	echo '  local orig_'"${cmd}"'="'"${orig_binary}"'"'
	echo '  local disable_ref="__DISABLE_'${cmd^^*}'_ALIAS"'
	echo '  local disable_ref2="__DISABLE_'${cmd^^*}'_MACRO"'
	echo '  local src_cmd="${orig_'${cmd}'}"'
	echo '  if [ -z "${!disable_ref}" ] && [ -z "${!disable_ref2}" ]; then'
	echo '    "${src_cmd}"' ${addn_args} '"$@"'
	echo '  else'
	echo '    "${src_cmd}" "$@"'
	echo '  fi'
	echo '}'
	echo 'export PATH="${OLDPATH}"'
	echo 'unset OLDPATH'
}

# Wrapper for alias_func_template
set_default_args() {
	local cmd="$1"
	shift
	
	local addn_args="$*"
	local code="$(alias_func_template)"
	eval "${code}"
}

# Colored output for ls & grep
set_default_args ls     --color=auto -la
set_default_args grep   --color=auto
set_default_args egrep  --color=auto
set_default_args fgrep  --color=auto
set_default_args zgrep  --color=auto
set_default_args zegrep --color=auto
set_default_args zfgrep --color=auto

if ! which gedit >/dev/null 2>/dev/null; then
	# Override gedit only if it's not in $PATH (OSX)
	gedit() {
		open -a gedit "$@"
	}
fi

# UNIX timestamp -> human-readable date
timestamp2date() {
	local ts="$1"
	shift

	date --date="@${ts}" "$@"
}

# Just date if more than week ago else 'N <timeunits> ago'
pretty_date() {
	local now="$(date +%s)"
	local ts="$1"
	local date_diff=$((now - ts))
	if   [[ ${date_diff} -gt $((7 * 86400)) ]]; then
		date '+%x %R' -d "@${ts}"
	elif [[ ${date_diff} -gt 86400 ]]; then
		echo $((date_diff / 86400)) 'days ago'
	elif [[ ${date_diff} -gt 3600 ]]; then
		echo $((date_diff / 3600)) 'hours ago'
	elif [[ ${date_diff} -gt 60 ]]; then
		echo $((date_diff / 60)) 'minutes ago'
	elif [[ ${date_diff} -gt 0 ]]; then
		echo 'Just now'
	else
		echo 'In the future'
	fi
}

# Pseudographic version of GitHub's Network pane
git_branches() {
	git log --graph --full-history --all --pretty=format:"%Cred%h%Creset%x09%ct%x09%Cgreen%d%Creset%x09%s" 
	# TODO: datetime update
	#| awk '{printf "%s\t%s\t", $1, $2; system ("echo pretty_date $3"); for (i = 4; i <= NF; i++) {printf "%s ", $i}; printf "\n"}'
}

# Template of function from python's urllib
pyurlalias_template() {
	arg="$1"
	local name="${arg%%=*}"
	local func="${arg#*=}"
	
	echo "${name}"'() {'
	echo '  python -c "import sys, urllib; print urllib.'"${func}"' (sys.stdin.read ())" "$@"'
	echo '}'
}

# Function generator
pyurlalias() {
	local code="$(pyurlalias_template $@)"
	eval "${code}"
}

# Encoding & decoding URL addresses
pyurlalias urlencode=quote
pyurlalias urlencode_p=quote_plus
pyurlalias urldecode=unquote
pyurlalias urldecode_p=unquote_plus

# To get some attention for background terminal
noize() {
	local beeps="${1:-5}"
	local delay="${2:-0.1}"
	
	for i in $(seq 1 "${beeps}"); do
		echo -ne '\a'
		sleep "${delay}"
	done
}

# Adds all files to SVN
svnaddall() {
	for i in *; do svn add $i@; done
}

# Counts number of lines, added, removed and edited by me
gitlogme() {
	git log --author='Kirill Bystrov' --pretty=tformat: --numstat | awk '{added += $1; removed += $2; total += $1 + $2} END {printf "added: %s; removed: %s; total: %s\n", added, removed, total}'
}

# Prints all the concurrently modified files in Git repository
git_conflicts() {
	git status | grep 'both modified:' | awk '{print $4}'
}

# __github [source] [action] [repo] [...]
__github() {
	local src="$1"
	shift
	local action="$1"
	shift
	local repo="$1"
	shift

	git "${action}" "https://github.com/${src}/${repo}" "$@"
}

# githubCP [action] [repo] [...]
githubCP() {
	__github "CleverPumpkin" "$@"
}

# githubCP [action] [repo] [...]
githubMe() {
	__github "byss" "$@"
}

# Copies Retina & non-Retina images at the same time
retinacp() {
	if [ "$#" -eq 2 ]; then
		local srcFile="$1"
		local retinaSrc="${srcFile%.*}@2x.${srcFile##*.}"
		if [ -f "${retinaSrc}" ] && [ -r "${retinaSrc}" ]; then
			local destFile="$2"
			local retinaDest="${destFile%.*}@2x.${destFile##*.}"
			cp "${retinaSrc}" "${retinaDest}"
		fi
	fi

	# Default copying should be done anyway
	cp "$@"
}

# Drops part of input lines with given probability
lines_sample() {
	local prob="$1"
	local awkProg=$(cat <<EOF
	BEGIN {
		srand ();
	}

	{
		FS="\n";
		if (rand () < ${prob}) {
			print \$0;
		}
	}
EOF
)
	awk "${awkProg}"
}

# Cross-platform way of getting real file path
py_realpath() {
	python -c 'import os, sys; print "\n".join ([os.path.realpath (p) for p in sys.argv [1:]])' "$@"
}

# bash-completion
if [ -f /opt/local/etc/profile.d/bash_completion.sh ]; then
	. /opt/local/etc/profile.d/bash_completion.sh
fi

# Prints out shell running time
shell_uptime() {
	local secs="${SECONDS}"
	local h=$((secs / 3600))
	local m=$(((secs - h * 3600) / 60 ))
	local s=$((secs % 60))
	local -a time_comps
	echo 'Shell is now running for' "${secs}" 'sec =' "${h}" 'h' "$(printf '%02d' ${m})" 'm' "$(printf '%02d' ${s})" 's.'
}

# Finds mentions of argument in Bash history file
hgrep() {
	local pattern="$1"
	grep "${pattern}" ~/.bash_history
}

# Export all defined here functions
declare -F | while read decl; do
	func="${decl##* }"
	func_info=$($(echo "${decl}" | sed 's/-f/-F/'))
	source_file="${func_info##* }"
	if [ "${source_file}" = "${BASH_SOURCE}" ]; then
		$(echo "${decl}" | sed 's/declare/export/')
	fi
done
unset func
unset func_info
unset source_file

