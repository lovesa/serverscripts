#!/bin/sh

csync2 -cr /
if csync2 -M; then
	echo "!!"
	echo "!! There are unsynced changes! Type ’yes’ if you still want to"
	echo "!! exit (or press crtl-c) and anything else if you want to start"
	echo "!! a new login shell instead."
	echo "!!"
	if read -p "Do you really want to logout? " in &&
	[ ".$in" != ".yes" ]; then
		echo -e "[1;31mYOU ARE LOGED IN AGAIN![0m"
		exec bash --login
	fi
fi

