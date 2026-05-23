BEGIN {
    blocks_init()
}

{
    blocks_process_line(normalize_input_line($0))
}

END {
    blocks_finish()
    render_document()
}

function normalize_input_line(line,    nul) {
    sub(/\r$/, "", line)

    # Some awk implementations expose NUL in $0, while others split or drop it
    # before program code can see it. Normalize it when the interpreter makes
    # that possible.
    nul = sprintf("%c", 0)
    if (nul != "") {
        gsub(nul, character_from_codepoint(65533), line)
    }

    return line
}
