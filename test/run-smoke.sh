#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 AWK AWKDOWN" >&2
    exit 2
fi

awk_bin=$1
awkdown=$2

run_awkdown() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 5 test/awkdown.sh "$awk_bin" "$awkdown"
    else
        test/awkdown.sh "$awk_bin" "$awkdown"
    fi
}

for input in test/smoke/*.md; do
    expected=${input%.md}.html
    actual="build/smoke-$(basename "${input%.md}").html"

    run_awkdown <"$input" >"$actual"
    diff -u "$expected" "$actual"
done

actual=build/smoke-crlf.html
expected=build/smoke-crlf.expected.html
printf 'alpha\r\n' | run_awkdown >"$actual"
printf '<p>alpha</p>\n' >"$expected"
diff -u "$expected" "$actual"

marker=$(printf '\034')
actual=build/smoke-inline-token-marker.html
expected=build/smoke-inline-token-marker.expected.html
printf 'a%s\n' "$marker" | run_awkdown >"$actual"
printf '<p>a%s</p>\n' "$marker" >"$expected"
diff -u "$expected" "$actual"

if printf 'a\000b\n' | "$awk_bin" '
    BEGIN {
        nul = sprintf("%c", 0)
    }
    NR == 1 && length($0) == 3 && length(nul) == 1 && index($0, nul) == 2 {
        ok = 1
    }
    END {
        exit ok ? 0 : 1
    }
'; then
    actual=build/smoke-nul.html
    expected=build/smoke-nul.expected.html
    printf 'a\000b\n' | run_awkdown >"$actual"
    printf '<p>a\357\277\275b</p>\n' >"$expected"
    diff -u "$expected" "$actual"
else
    printf 'a\000b\n' | run_awkdown >/dev/null
fi
