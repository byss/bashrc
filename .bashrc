#!/bin/bash

##### DEBUG ONLY #####
# set -v
######################

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
export EDITOR='/usr/local/bin/nano'

# Python startup
export PYTHONSTARTUP="${HOME}/.pythonrc.py"

# Laaaaaaaarge history
export HISTFILESIZE=1048576
export HISTSIZE=1048576

# History tuning
export HISTCONTROL="ignoredups"

# Saves history to HISTFILE ASAP
export PROMPT_COMMAND="history -a; ${PROMPT_COMMAND}"

# Shell options
shopt -s autocd                  # ./dir <=> cd dir
shopt -s cdspell                 # autocorrection
shopt -s checkwinsize            # always have actual $LINES & $COLUMNS
shopt -u cmdhist                 # use semicolon instead of newline
shopt -u direxpand               # do not expand tilde and so on
shopt -s dotglob                 # echo * sees dotfiles
shopt -s extdebug                # MOAR debugging
shopt -s globstar                # '**' support
shopt -u gnu_errfmt              # POSIX, not GNU error messages
shopt -s histappend              # Appends history to $HISTFILE instead of overwriting
shopt -s huponexit               # kill all bg jobs on exit
shopt -u lithist                 # use semicolons instead of newlines in history
shopt -s no_empty_cmd_completion # empty command completion is stupid
shopt -u nocaseglob              # filenames ARE case-sensitive
shopt -u nocasematch             # comparisons ARE case-sensitive
shopt -s xpg_echo                # echo has '-e' by default

# bash-completion
[ -f /usr/local/share/bash-completion/bash_completion ] && . /usr/local/share/bash-completion/bash_completion
# Apple's take on bash-completion for Git
[ -f /Applications/Xcode.app/Contents/Developer/usr/share/git-core/git-completion.bash ] && . /Applications/Xcode.app/Contents/Developer/usr/share/git-core/git-completion.bash

__BASHRC_LOCKSDIR="${HOME}/tmp/.bashrc_locks"
mkdir -p "${__BASHRC_LOCKSDIR}"

# Returns named lock absolute path
__lock() {
	echo "${__BASHRC_LOCKSDIR}/.$1_lockdir"
}

# Attempts to atomically create an new temporary file
__lock_trylock() {
	mkdir "$(__lock "$1")" > /dev/null 2>&1
}

# Basename of a special (as in "regular files" vs "block device pseudofile", namely FIFO in this particular case) file
# enabling non-busy waits on locks. Wait is induced via read attempt from such file and lasts until any write operation.
__BASHRC_LOCK_WAITABLE="waitable.$$"

# Repeatedly attempts to acquire a lock until the operation succeeds
__lock_lock() {
	local lock_waitable="$(__lock "$1")/${__BASHRC_LOCK_WAITABLE}"
	mkfifo "${lock_waitable}"
	if __lock_trylock "$1"; then
		for waitable in "$(find "$(__lock "$1")" -name 'waitable.*')"; do
			if [ "${waitable}" == "${lock_waitable}" ] || ! ps "$(basename "${waitable}" | head -c -9)" > /dev/null 2>&1; then
				rm -f "${waitable}"
			fi
		done
	else
		: < "${lock_waitable}"
	fi
}

# Removes lock file of one exists
__lock_unlock() {
	local lockdir="$(__lock "$1")"
	rm -f "${lockdir}/${__BASHRC_LOCK_WAITABLE}"
	
	next_waitable="$(find "$(__lock "$1")" -name 'waitable.*' | head -n 1)"
	if [ -z "${next_waitable}" ]; then
		# Last process for this lock
		rm -rf "${lockdir}" # Effectively supporting lock-related temp files placement in the lock directory itself
	else
		# At least one process is still waiting on this lock
		: > "${next_waitable}" # Simply wake next blocked shell
		return
	fi
}

# Create a lock file and evaluate remaining arguments on successful creation, then remove the created file.
# Does nothing if the lock file is already existing. In other words, this function provides a non-blocking
# mutex-like interface to ensure only single command instance is running at a time, which is crucial to 
# have in some contexts like multiple shell instances being started in parallel.
__try_synchronized() {
	local lockName="$1"
	shift
	__lock_trylock "${lockName}" || return
	"$@"
	__lock_unlock "${lockName}"
}

# Same as __try_synchronized(), but doesn't immediately return when lock can not be acquired but rather when the
# lock is being removed.
__synchronized() {
	local lockName="$1"
	shift
	__lock_lock "${lockName}"
	"$@"
	__lock_unlock "${lockName}"
}

__write_out_swift_package_completion_script() {
	swift package completion-tool generate-bash-script > "$1"
	. "$1"
}

__SPM_COMPLETION_LOCK='spm-completion-gen'
if which -s swift; then
	__SPM_COMPLETION_SCRIPT="$(__lock "${__SPM_COMPLETION_LOCK}")/result.sh"
	__try_synchronized "${__SPM_COMPLETION_LOCK}" __write_out_swift_package_completion_script "${__SPM_COMPLETION_SCRIPT}" && __SPM_COMPLETION_SCRIPT=
fi

which thefuck > /dev/null 2>/dev/null && eval "$(thefuck --alias)"

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
expand_path "~/local/bin" # some stuff
expand_path "~/.fastlane/bin" # Fastlane tools
expand_path "/usr/local/opt/coreutils/libexec/gnubin" # Homebrew
expand_path "$(xcode-select -p)/usr/bin" # Xcode Developer utils
expand_path "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin" # Xcode Developer Toolchain
expand_path "/usr/local/opt/flex/bin" # GNU Flex
expand_path "/usr/local/opt/bison/bin" # GNU Bison
expand_path "/usr/local/opt/gettext/bin" # GNU Gettext
expand_path "/usr/local/opt/gnu-sed/libexec/gnubin" # GNU Sed
expand_path "/usr/local/opt/sphinx-doc/bin" # Sphinx

MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"

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

__random_ext() {
	local extChars="abcdefghijklmnopqrstuvwxyz1234567890"
	local result=""
	for i in $(seq 1 10); do
		result="${result}${extChars:$(($RANDOM % ${#extChars})):1}"
	done
	echo "${result}"
}

__backup_command() {
	local cmd="$1"
	local cmdType="$(type -t "${cmd}")"
	if [ "$?" -ne 0 ]; then
		echo "__backup_command: ${cmd}: command not found" >&2
		return 1
	fi

	local backupCmd=""
	while :; do
		backupCmd="__${cmd}_backup_$(__random_ext)"
		if ! type -t "${backupCmd}" >/dev/null; then
			break
		fi
	done

	case "${cmdType}" in
		"alias")
			eval "$(alias "${cmd}" | sed "s/^alias ${cmd}=/alias ${backupCmd}=/")"
			unalias "${cmd}"
			;;

		"keyword")
			echo "__backup_command: ${cmd}: is shell keyword" >&2
			return 1
			;;

		"function")
			eval "${backupCmd}() { $(declare -f ${cmd} | tail -n +2) }"
			unset -f "${cmd}"
			;;

		"builtin")
			backupCmd="builtin ${cmd}"
			;;

		"file")
			backupCmd="$(which ${cmd})"
			;;
	esac

	echo "${backupCmd}"
}

__extend_command_func() {
	local cmd="${1}"
	shift
	local ORIG_CMD="$(__backup_command "${cmd}")"
	if [ "$?" -ne 0 ]; then
		return 1
	fi
	local funcName="${1}"
	shift
	local funcArgs="$@"

	echo "${cmd}"'() {'
	echo '	if type -t "${__DISABLE_'"${cmd^^}"'_MACRO}" >/dev/null || type -t "${__DISABLE_'"${cmd^^}"'_ALIAS}" >/dev/null; then'
	echo '		'"${ORIG_CMD}" '"$@"'
	echo '	else'
	eval "${funcName} ${funcArgs}"
	echo '	fi'
	echo '}'
}

__extend_command_args_helper() {
	local cmd="${1}"
	shift

	echo -E "${ORIG_CMD}" "$@" '"$@"'
}

__extend_command_args() {
	local cmd="${1}"

	__extend_command_func "${cmd}" '__extend_command_args_helper' "$@"
}

__extend_command_alias_helper() {
	local aliasBase="${1}"
	shift

	echo -E "${aliasBase}" "$@" '"$@"'
}

__extend_command_alias() {
	local cmd="${1}"
	shift
	local aliasBase="${1}"
	shift

	__extend_command_func "${cmd}" '__extend_command_alias_helper' "${aliasBase}" "$@"
}

# Overrides default command behaviour if possible
# Usage: extend_command <command> <options>
# Options: -t [func|args]  Extension type.
#                          `func' replaces the command implementation with evaluated output
#                           value of function(s) passed after this option. ${ORIG_CMD} is
#                           replaced with backuped original command call.
#                          `alias` works exactly as defining a shell alias for the command
#                          `args' extension type just adds supplied arguments to original
#                          command implementation. This type is default and is used when no
#                          -t option is supplied.
extend_command() {
	local cmd="${1}"
	shift

	local endOfOptions="no"
	local extendFunc="__extend_command_args"
	while [ "${endOfOptions}" == "no" ]; do
		local arg="${1}"
		case "${arg}" in
			"-t")
				local extType="${2}"
				case "${extType}" in
					"func")
						extendFunc="__extend_command_func"
						;;
					"alias")
						extendFunc="__extend_command_alias"
						;;
				esac
				shift 2
				;;
			*)
				endOfOptions="yes"
				;;
		esac
	done

	#echo "$(${extendFunc} ${cmd} $@)"
	eval "$(${extendFunc} ${cmd} $@)"
}

# Colored output for ls & grep
extend_command ls     --color=auto -la
extend_command grep   --color=auto
extend_command egrep  --color=auto
extend_command fgrep  --color=auto
extend_command zgrep  --color=auto
extend_command zegrep --color=auto
extend_command zfgrep --color=auto

extend_command nano   -c            # Line numbers
extend_command diff   -ru           # Unified and recursive diff
extend_command xargs  -d "\'\\\n\'" # Sets arguments separator to newline instead of any whitespace

__gedit_impl() {
	for f in "$@"; do
		[ ! -e "${f}" ] && touch "${f}"
		[ -e "${f}" ] && open -a bbedit "${f}"
	done
}

extend_command gedit -t alias __gedit_impl
extend_command edit  -t alias __gedit_impl
extend_command beep  -t alias afplay '/System/Library/Sounds/Glass.aiff'

__LESS_HOOKS=( check_plist )

__less_hook_check_plist() {
	local fileType="${1}"
	if [ "$fileType" == "Apple binary property list" ]; then
		echo "__less_binary_plist"
	fi
}

__less_binary_plist() {
	local lessBinary="${1}"
	shift
	local lessFile="${1}"
	shift

	plutil -convert xml1 -o - "${lessFile}" | "${lessBinary}" "$@"
}

__less_check_hooks() {
	echo 'if [ $# -lt 1 ]; then "'"${ORIG_CMD}"'"; return; fi'

	echo 'local lessFile="$1"'
	echo 'shift'

	echo 'local hookFunc=""'
	echo 'if [ -r "${lessFile}" ]; then'
	echo '	local fileType="$(file -b "${lessFile}")"'
	echo '	for hook in '"${__LESS_HOOKS[@]}"'; do'
	echo '		hookFunc="$(__less_hook_${hook} "${fileType}")"'
	echo '		if [ ! -z "${hookFunc}" ]; then'
	echo '			break'
	echo '		fi'
	echo '	done'
	echo 'fi'

	echo '${hookFunc} "'"${ORIG_CMD}"'" "${lessFile}" -FX "$@"'
}

extend_command less -t func __less_check_hooks # Adds some input filters for `less' command

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
__pyurlalias_template() {
	arg="$1"
	local name="${arg%%=*}"
	local func="${arg#*=}"

	echo "${name}"'() {'
	echo '  python -c "import sys, urllib; print urllib.'"${func}"' (sys.stdin.read ())" "$@"'
	echo '}'
}

# Function generator
__pyurlalias() {
	local code="$(__pyurlalias_template $@)"
	eval "${code}"
}

# Encoding & decoding URL addresses
__pyurlalias urlencode=quote
__pyurlalias urlencode_p=quote_plus
__pyurlalias urldecode=unquote
__pyurlalias urldecode_p=unquote_plus

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
	for i in *; do svn add "${i}@"; done
}

# Counts number of lines, added, removed and edited by me
gitlogme() {
	git log --author='Kirill Bystrov' --pretty=tformat: --numstat | awk '{added += $1; removed += $2; total += $1 + $2} END {printf "added: %s; removed: %s; total: %s\n", added, removed, total}'
}

# Prints all the concurrently modified files in Git repository
git_conflicts() {
	git status | grep 'both modified:' | awk '{print $4}'
}

# _git_srv [srv] [source] [action] [repo] [...]
_git_srv() {
	local srv="$1"
	shift
	local src="$1"
	shift
	local action="$1"
	shift
	local repo="$1"
	shift

	git "${action}" "${srv}/${src}/${repo}" "$@"
}

# _github [source] [action] [repo] [...]
_github() {
	_git_srv "https://github.com" "$@"
}

# githubCP [action] [repo] [...]
githubCP() {
	_github "CleverPumpkin" "$@"
}

# githubCP [action] [repo] [...]
githubMe() {
	_github "byss" "$@"
}

# byssGit [action] [repo] [...]
byssGit() {
	_git_srv "ssh://byss-home.tk:23293" "git" "$@"
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
__setup_realpath() {
	if ! which realpath &>/dev/null; then
		local py_realpath_src=$(cat <<EOF
			realpath() {
				python -c 'import os, sys; print "\n".join ([os.path.realpath (p) for p in sys.argv [1:]])' "$@"
			}
EOF
)
		eval "${py_realpath_src}"
	fi
}
__setup_realpath

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
	grep "${pattern}" "${HISTFILE}"
}

# Finds dSYMs by UUID
dsymfind() {
	if [ "$#" -eq 1 ]; then
		mdfind "com_apple_xcode_dsym_uuids == $1"
		return
	fi

	while [ "$#" -gt 0 ]; do
		echo -n "$1: "
		dsymfind "$1"
		shift
	done
}

__php_linewrap() {
	echo "${ORIG_CMD}" '"$@"'
	echo 'echo'
}

extend_command php -t func '__php_linewrap' # Automatically adds echo "\n"; to every php -r call

__git_reject_unsigned_tags() {
	cat <<EOF
	local is_tag_command="no"
	for arg in "\$@"; do
		if [ "x\${arg}" = 'xtag' ]; then
			is_tag_command='yes'
		elif [ "x\${is_tag_command}" = 'xyes' ] && [ "x\${arg}" = 'x-a' ]; then
			echo "FUCK YOU BIATCH SIGN YOUR SHIT" >&2
			return 137
		fi
	done

	"${ORIG_CMD}" "\$@"
EOF
}

extend_command git -t func '__git_reject_unsigned_tags' # Rejects git tag -a

# Checks for changes in local and remote dotfiles.
# Dotfiles repo is read from $BASHRC_DOTFILES_REPO_PATH; default path is ~/bashrc.
diff_dotfiles() {
	local localSubdir="${1:-.}"
	local dotfilesRepo="${BASHRC_DOTFILES_REPO_PATH:-$(realpath ~/bashrc)}"
	pushd "${dotfilesRepo}" > /dev/null
	echo "Path: ${dotfilesRepo}"
	for item in *; do
		local repoItem="${item}"
		local localItem="~/${localSubdir}/${item}"
		if [ -r "${repoItem}" ] && [ -r "${localItem}" ]; then
			if [ -f "${repoItem}" ] && [ -f "${localItem}" ]; then
				diff "${repoItem}" "${localItem}"
			elif [ -d "${repoItem}" ] && [ -d "${localItem}" ]; then
				local subdir="${item}"
				local repoSubdir="$(realpath ${repoItem})"
				BASHRC_DOTFILES_REPO_PATH="${repoSubdir}" diff_dotfiles "${subdir}"
			fi
		fi
	done | less
	popd > /dev/null
}

__wtfhd_sigint_trap_tmpl() {
	echo '__wtfhd_sigint_trap() {'
	local oldTrap="$1"
	echo "	$oldTrap"
	echo '}'
}

# Shows files & dirs list sorted by size ascending.
# Search scope is function's argument or root directory if no argument supplied.
wtfhd() {
	local oldSigintTrap="$(trap -p SIGINT | awk '{print $3}' | sed "s/^'//;s/'$//")"
	eval "$(__wtfhd_sigint_trap_tmpl "${oldSigintTrap}")"
	trap __wtfhd_sigint_trap SIGINT

	local path="${1:-/}"
	pushd "${path}" > /dev/null
	local sizeInfo=$(du -ahd 1 2>/dev/null | sort -h)
	local sizeInfoRev=$(echo "${sizeInfo}" | tac)
	unset WTFHD_LARGEST_DIR
	local largestDir="$(
		echo "${sizeInfoRev}" | while read sizeInfoLine; do
			local infoDir=$(echo "${sizeInfoLine}" | awk '{print $2}')
			if [ "${infoDir}" != '.' ] && [ -d "${infoDir}" ] ; then
				realpath "${infoDir}"
				break
			fi
		done
	)"
	if [ ! -z "${largestDir}" ]; then
		export WTFHD_LARGEST_DIR="${largestDir}"
	fi
	echo "${sizeInfo}"
	popd > /dev/null

	trap "${oldTrap:--}" SIGINT
}

# Changes dir to largest found one.
# This function checks run results of last wtfhd() and changes directory to largest item if it is a directory, otherwise it does effectively nothing.
cdToLargest() {
	if [ ! -z "${WTFHD_LARGEST_DIR}" ] && [ -d "${WTFHD_LARGEST_DIR}" ]; then
		cd "${WTFHD_LARGEST_DIR}"
	fi
}

# Returns models of current Mac device, i.e. "Macbook5,1"
macdevModel() {
	sysctlInfo="$(sysctl hw.model 2>/dev/null)"
	local sysctlResult="$?"

	if [ "${sysctlResult}" -eq 0 ]; then
		echo "${sysctlInfo}" | sed -E 's/^hw\.model\\s*[:=]//'
	else
		echo "Are you really using Mac?"
	fi
	unset sysctlInfo

	return "${sysctlResult}"
}

# Displays last used commands list.
# Usage: lastCmds [COUNT]
lastCmds() {
	local DEFAULT_COUNT=10

	local count="$1"
	if ! [ "${count}" -gt 0 ] 2>/dev/null; then
		count="${DEFAULT_COUNT}"
	fi

	tail -n "${count}" "${HISTFILE}"
}

# Visualizes command return code
# Usage: __chkCmd [SHOW_OUTPUT] [COMMAND_1] [COMMAND_2] É [COMMAND_N]
# Commands stderr & stdout are enabled if and only if SHOW_OUTPUT is nonempty
__chkCmd() {
	local suppressOutput
	if [ "${#1}" -gt 0 ]; then
		suppressOutput="NO"
	else
		suppressOutput="YES"
	fi
	shift

	local CMD_LEN_LIMIT=40
	local maxCmdLen=0

	local cmds=()
	local cmdOutputs=()

	while [ "$#" -gt 0 ]; do
		local cmd="$1"
		shift

		local displayCmd="${cmd:-<Nothing>}"
		if [ "${#cmd}" -gt "${CMD_LEN_LIMIT}" ]; then
			displayCmd="${displayCmd:0:$((CMD_LEN_LIMIT - 1))}É"
		fi
		cmds+=( "${displayCmd}" )

		local displayCmdLen="${#displayCmd}"
		if [ "${displayCmdLen}" -gt "${maxCmdLen}" ]; then
			if [ "${displayCmdLen}" -le "${CMD_LEN_LIMIT}" ]; then
				maxCmdLen="${displayCmdLen}"
			else
				maxCmdLen="${CMD_LEN_LIMIT}"
			fi
		fi

		if [ "${suppressOutput}" == "YES" ]; then
			exec 3<&0 4>&1 6>&2 </dev/null >/dev/null 2>/dev/null
		fi

		local cmdResult
		${cmd}
		local cmdCode="$?"

		if [ "${cmdCode}" -eq 0 ]; then
			cmdResult="True/Success "
		else
			cmdResult="False/Failure"
		fi
		cmdOutputs+=( "${cmdResult} (RET: ${cmdCode})" )

		if [ "${suppressOutput}" == "YES" ]; then
			exec 0<&3 3<&- 1>&4 4>&- 2>&6 6>&-
		fi
	done

	for cmdN in $(seq 0 $((${#cmds[*]} - 1))); do
		printf "%${maxCmdLen}s: %s\n" "${cmds[${cmdN}]}" "${cmdOutputs[${cmdN}]}"
	done
}

# Visualizes command return code
# Usage: chkCmd [COMMAND_1] ';' [COMMAND_2] ';' É ';' [COMMAND_N]
# NOTE: stderr & stdout are redirected to /dev/null while executing commands
chkCmd() {
	__chkCmd '' "$@"
}

# Visualizes command return code
# Usage: chkCmdDbg [COMMAND_1] ';' [COMMAND_2] ';' É ';' [COMMAND_N]
# NOTE: commands output is fully preserved
chkCmdDbg() {
	__chkCmd 'SHOW' "$@"
}

# Shortcut for 'open -a "Keychain Access"'
openKeychain() {
	open -a 'Keychain Access'
}

localCC() {
	localCompile "$1" 'gcc'
}

localObjC() {
	localCompile "$1" 'clobjc'
}

localCompile() {
	local src="$1"
	shift
	local compiler="$@"

	local found=""
	local foundTwice=""
	local ext=""
	local sourceFile=""

	for maybeExt in "" ".c" ".m" ".cpp" ".cxx"; do
		local maybeSourceFile=~/local/src/"${src}${maybeExt}"
		if [ -f  "${maybeSourceFile}" ]; then
			if [ ! -z "${found}" ]; then
				echo 'Ambigous source file' "${src}" >&2
				return 1
			else
				found="YES"
				ext="${maybeExt}"
				sourceFile="${maybeSourceFile}"
			fi
		fi
	done
	if [ -z "${found}" ]; then
		echo 'Source file' "${src}" 'is not found'
		return 2
	fi

	local executable=~/local/bin/"$(basename "${src}" "${ext}")"
	${compiler} "${sourceFile}" -o "${executable}"
}

clear_tmp() {
	local TMP_DIR=~/"tmp"
	local MAX_AGE_DAYS=7                 # Delete files older than a week
	local MIN_CLEAN_INTERVAL=$(( 3600 )) # At least one hour between cleans
	local LAST_CLEAN_FILE="${TMP_DIR}/.lastclean"

	local currentTimestamp="$(date '+%s')"
	local lastCleanDate="$(stat "${LAST_CLEAN_FILE}" -c '%Y')"
	if [ $(( currentTimestamp - lastCleanDate )) -lt "${MIN_CLEAN_INTERVAL}" ]; then
		return 0
	fi

	touch "${LAST_CLEAN_FILE}"
	find "${TMP_DIR}" -mindepth 1 -mtime "+${MAX_AGE_DAYS}" -not -wholename "${LAST_CLEAN_FILE}" -delete
}
clear_tmp

# Moves a git tag
git_move_tag() {
	local tag="$1"
	shift

	local tagMessage="$(git cat-file -p $(git rev-parse "${tag}") | tail -n +6  | sed -e '/-----BEGIN PGP SIGNATURE-----/q' | sed -e '/-----BEGIN PGP SIGNATURE-----/d')"
	git tag -d "${tag}" && git push origin ":refs/tags/${tag}" && git tag -s "${tag}" -m "${tagMessage}" "$@" && git push --tags
}

# Checks that iTerm integrations are installed and are of latest version
check_etc_bashrc_iterm() {
	[ "iTerm.app" == "${TERM_PROGRAM}" ] || return

	local itermrc="/etc/bashrc_${TERM_PROGRAM}"
	if [ ! -r "${itermrc}" ]; then
		echo "${RED_COLOR}!!! ${BOLD}${TERM_PROGRAM} integrations are NOT installed${NORMAL}${RED_COLOR} !!!${NORMAL}"
		return
	fi

	local serverTimestamp="$(curl -m 2 -sz ${itermrc} -I 'https://iterm2.com/misc/bash_startup.in' | grep '^Last-Modified: ' | cut -d ' ' -f 2- | tr -d '\r')"
	[ -z "${serverTimestamp}" ] || echo "${YELLOW_COLOR}! ${BOLD}${TERM_PROGRAM} integrations updated; latest version is ${serverTimestamp}${NORMAL}${YELLOW_COLOR} !${NORMAL}\n! Use \`download_latest_enc_bashrc_iterm' to download it !"
}
check_etc_bashrc_iterm

# Downloads latest iTerm integrations script
download_latest_enc_bashrc_iterm() {
	local itermrc="/etc/bashrc_${TERM_PROGRAM}"
	sudo curl -z "${itermrc}" -R 'https://iterm2.com/misc/bash_startup.in' -o "${itermrc}"
}

# Converts a video to GIF
vid2gif() {
	local video="$1"
	local gif="$2"


}

__symcrash_xcver() {
	while [ $# -gt 0 ]; do
		if [ "$1" = '-xcode' ]; then
			echo "$2"
			break
		fi
		shift
	done
}

# Symbolicate crash
symcrash() {
	local xcver="$(__symcrash_xcver "$@")"
	echo "$@"
	( DEVELOPER_DIR="/Applications/Xcode${xcver}.app/Contents/Developer" "/Applications/Xcode${xcver}.app/Contents/SharedFrameworks/DVTFoundation.framework/Resources/symbolicatecrash" "$@" ) | less
}

# Upload an Xcode archive to App Store Connect
xcarchiveupload() {
	while [ "$#" -gt 0 ]; do
		xcodebuild -allowProvisioningUpdates -exportArchive -exportOptionsPlist ~/Projects/UploadToASCOptions.plist -archivePath "$1"
		shift
	done
}

# Lists all functions defined in this file
bashrc_funcs() {
	local print_int=
	if [ "${1,,}" = "yes" ]; then
		print_int="yes"
	fi
	declare -F | while read decl; do
		local func="${decl##* }"
		local func_info=$($(echo "${decl}" | sed 's/-f/-F/'))
		local source_file="${func_info##* }"
		if [ "${source_file}" = "${BASH_SOURCE}" ]; then
			if [ "${func::2}" != "__" ] || [ ! -z "${print_int}" ]; then
				echo "${func}"
			fi
		fi
	done
}

# Prints documenting comment for a functions defined here
# Works with multiline comments too
# Usage: func_help [FUNCTION NAME]
func_help() {
	local func="${1:-func_help}"
	local info_code=$(declare -F "${func}" | awk '{print "local first_line=\""$2"\""; printf "local source_file=\""; for (i = 3; i < NF; i++) {printf $i" ";} printf $NF"\"";}')
	eval "${info_code}"
	local help_lines=0
	while head -n $((first_line - help_lines - 1)) "${source_file}" | tail -n 1 | egrep -o '^\s*#' &>/dev/null; do
		help_lines=$((help_lines + 1))
	done
	if [ $((help_lines)) -gt 0 ]; then
		echo "Help on ${func}:"
		head -n $((first_line - 1)) "${source_file}" | tail -n $((help_lines)) | sed -E 's/^[[:space:]]*#[[:space:]]*/  /'
		if [ "${func}" = "${FUNCNAME}" ]; then
			echo '\n  Functions, declared in this .bashrc:'
			bashrc_funcs | sed 's/^/    /'
		fi
	fi
}

export PATH="$HOME/.fastlane/bin:$PATH"

__simctl_completion() {
	if [ "${#COMP_WORDS[@]}" -eq 2 ]; then
		COMPREPLY=( $(compgen -W "${__SIMCTL_COMMANDS}" "${COMP_WORDS[-1]}") )
	elif [ "${#COMP_WORDS[@]}" -gt 2 ] && [ "${COMP_WORDS[1]}" == 'help' ]; then
		if [ "${#COMP_WORDS[@]}" -eq 3 ]; then
			COMPREPLY=( $(compgen -W "${__SIMCTL_COMMANDS}" "${COMP_WORDS[-2]}") )
		fi
	else
		local subcommand="${COMP_WORDS[1]}"
		local subcommandFormatString="${__SIMCTL_SUBCOMMANDS[${subcommand}]}"
		if [ -z "${subcommandFormat}" ]; then
			subcommandFormatString="$(simctl help "${subcommand}" 2>&1 | perl -pe 's/^[^U][^s][^g][^e][^:].*$\\n//; s/^Usage: simctl $ENV{"subcommand"}//; while (s/(<[_\w]*[^\\])(?<!>)\s+/\1_/) {}; s/[<>]//g' )"
			__SIMCTL_SUBCOMMANDS[${subcommand}]="${subcommandFormatString}"
		fi

		local subcommandFormat=( ${subcommandFormatString} )

		local termIndex=$(( ${#COMP_WORDS[@]} - 2 ))
		local term="${subcommandFormat[${termIndex}]}"
		case "${term}" in
			"device")
				COMPREPLY=( $(IFS="$(printf '\n')" compgen -W "${__SIMCTL_DEVICES}" "${COMP_WORDS[-1]}") )
				;;

			"device_type_id")
				COMPREPLY=( $(compgen -W "${__SIMCTL_DEVICE_TYPES}" "${COMP_WORDS[-1]}") )
				;;

			"runtime_id")
				COMPREPLY=( $(compgen -W "${__SIMCTL_DEVICE_TYPES}" "${COMP_WORDS[-1]}") )
				;;
		esac
	fi

	COMPREPLY=( "${COMPREPLY[@]}" )
}

__simctl_completion_prepare() {
	export __SIMCTL_COMMANDS="$(simctl help | sed -E -e '/^[[:print:]]/d' -e '/^$/d' -e 's/^[[:space:]]+([[:alnum:][:punct:]]+).*/\1/')"

	declare -A __SIMCTL_SUBCOMMANDS

	local allDevicesInfo="$(simctl list -j)"
	export __SIMCTL_DEVICE_TYPES="$(echo "${allDevicesInfo}" | jq --raw-output '.devicetypes[] | .name, .identifier')"
	export __SIMCTL_RUNTIMES="$(echo "${allDevicesInfo}" | jq --raw-output '.runtimes[] | .name, .identifier')"
	export __SIMCTL_DEVICES="$(printf 'booted\\n')$(echo "${allDevicesInfo}" | jq --raw-output '.devices[][] | .name, .udid')"
}

# __simctl_completion_prepare
# complete -F __simctl_completion simctl

[ -e "~/.iterm2_shell_integration.bash" ] && . "${HOME}/.iterm2_shell_integration.bash"
[ -e "~/.anka/bash_completion.sh" ] && . "~/.anka/bash_completion.sh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/byss/Downloads/google-cloud-sdk/path.bash.inc' ]; then . '/Users/byss/Downloads/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/byss/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . '/Users/byss/Downloads/google-cloud-sdk/completion.bash.inc'; fi

if [ ! -z "${__SPM_COMPLETION_SCRIPT}" ]; then
	__synchronized "${__SPM_COMPLETION_LOCK}" source "${__SPM_COMPLETION_SCRIPT}"
fi
