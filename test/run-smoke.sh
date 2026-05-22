#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 AWK AWKDOWN" >&2
    exit 2
fi

awk_bin=$1
awkdown=$2

for input in test/smoke/*.md; do
    expected=${input%.md}.html
    actual="build/smoke-$(basename "${input%.md}").html"

    test/awkdown.sh "$awk_bin" "$awkdown" <"$input" >"$actual"
    diff -u "$expected" "$actual"
done

