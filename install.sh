#!/bin/sh
#
# Install tm package
#
# Default is /usr/local/bin unless other target given.

set -e  # Exit on any error
set -u  # Unitialized variable is an error

target=${1:-/usr/local/bin}

if test ! -d ${target} ; then
    mkdir -p ${target}
fi

install -m 755 tm.sh ${target}/tm
install -m 755 tm-cmd.sh ${target}/tm-cmd

exit 0
