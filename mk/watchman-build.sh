#!/bin/sh

# Requires:
#
# fedora/ubuntu packages: mplayer, sound-theme-freedesktop

cfg_tty=""
cfg_dir=""
cfg_cmd=make
cfg_xterm_cls=""

errx()
{
	echo "`basename $0` error: $1" 1>&2
	exit 1
}

warnx()
{
	echo "`basename $0` warning: $1" 1>&2
}

# Return >=1 on error.
prerequisites()
{
	local r=0
	for idx in "$@"
	do
		which $idx > /dev/null 2>&1 || {
			warnx "'$idx' not found in path"
			r=$((r+1))
		}
	done

	return $r
}

play()
{
	local times
	local sound

	times=1
	sound=message.oga

	[ "$1" = 'error' ] && {
		times=3
		sound=bell.oga
	}

	mplayer -really-quiet -loop $times \
			/usr/share/sounds/freedesktop/stereo/$sound
}

usage()
{
	echo "usage: `basename $0` -t TTY [ -d DIR] [-c CMD] [-x]"
	echo ""
	echo '-t TTY    use `tty`, for example'
	echo "-d DIR    a directory to cd before running Make"
	echo "-c CMD    a command to run (default: ${cfg_cmd})"
	echo "-x        clean xterm history before every run"
	exit 1
}

# Main

while getopts d:t:c:xh opt
do
	case $opt in
		t)
			cfg_tty=$OPTARG
			;;
		d)
			cfg_dir=$OPTARG
			;;
		c)
			cfg_cmd=$OPTARG
			;;
		x)
			cfg_xterm_cls=true
			;;
		*|h)
			usage
			;;
	esac
done
shift `expr $OPTIND - 1`

prerequisites date seq mplayer || exit 1
[ ! -d /usr/share/sounds/freedesktop/stereo ] && \
	errx "install sound-theme-freedesktop package"

[ -z "$cfg_tty" ] && usage
[ -z "$cfg_dir" ] || {
	cd "$cfg_dir" > $cfg_tty 2>&1 || exit 1
}

if [ -z "$cfg_xterm_cls" ]; then
	printf "\n\n\033[7m%s\033[27m\n" "`date`" > $cfg_tty
else
	printf "\033c" > $cfg_tty # clear xterm history
fi

$cfg_cmd > $cfg_tty 2>&1

if [ $? -eq 0 ]; then
	play ok
else
	printf "\033[05t" > $cfg_tty
	play error
fi
