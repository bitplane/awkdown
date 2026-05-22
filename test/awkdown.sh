#!/bin/sh
set -eu

if [ "$#" -lt 2 ]; then
    echo "usage: $0 AWK AWKDOWN [ARGS...]" >&2
    exit 2
fi

awk_bin=$1
awkdown=$2
shift 2

# shellcheck disable=SC2086
exec $awk_bin -f "$awkdown" "$@"

