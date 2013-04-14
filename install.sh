#!/bin/sh
#
# Install tm package
#
# Default is /usr/local/bin unless other target given.

set -e  # Exit on any error
set -u  # Unitialized variable is an error

target=${1:-/usr/local/bin}

if test ! -d ${target} ; then
    echo "Creating ${target}"
    mkdir -p ${target}
fi

echo "Installing ${target}/tm"
install -m 755 tm.sh ${target}/tm

echo "Success."
exit 0
