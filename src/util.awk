function html_escape(text,    escaped) {
    escaped = text
    gsub(/&/, "\\&amp;", escaped)
    gsub(/</, "\\&lt;", escaped)
    gsub(/>/, "\\&gt;", escaped)
    gsub(/"/, "\\&quot;", escaped)
    return escaped
}

function html_attr_escape(text) {
    return html_escape(text)
}

function escape_disallowed_raw_html(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "<" && is_disallowed_raw_html_tag_at(text, i)) {
            out = out "&lt;"
        } else {
            out = out ch
        }
    }
    return out
}

function escape_disallowed_raw_html_block(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "<" && is_disallowed_raw_html_block_tag_at(text, i)) {
            out = out "&lt;"
        } else {
            out = out ch
        }
    }
    return out
}

function is_disallowed_raw_html_tag_at(text, pos,    rest, name) {
    rest = substr(text, pos + 1)
    sub(/^\//, "", rest)
    if (rest !~ /^[A-Za-z]/) {
        return 0
    }
    name = tolower(rest)
    sub(/[^a-z].*$/, "", name)
    return name ~ /^(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)$/
}

function is_disallowed_raw_html_block_tag_at(text, pos,    rest, name) {
    rest = substr(text, pos + 1)
    sub(/^\//, "", rest)
    if (rest !~ /^[A-Za-z]/) {
        return 0
    }
    name = tolower(rest)
    sub(/[^a-z].*$/, "", name)
    return name ~ /^(xmp|iframe|noembed|noframes|plaintext)$/
}

function ltrim(text) {
    sub(/^[ \t\r\n]+/, "", text)
    return text
}

function rtrim(text) {
    sub(/[ \t\r\n]+$/, "", text)
    return text
}

function trim(text) {
    return rtrim(ltrim(text))
}

function is_blank(line) {
    return line ~ /^[ \t]*$/
}

function leading_spaces(line,    i, col, ch) {
    col = 0
    for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (ch == " ") {
            col++
        } else if (ch == "\t") {
            col += 4 - (col % 4)
        } else {
            break
        }
    }
    return col
}

function strip_indent(line, count,    i, col, ch, next_col, rest) {
    col = 0
    for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1)

        if (ch == " ") {
            next_col = col + 1
        } else if (ch == "\t") {
            next_col = col + 4 - (col % 4)
        } else {
            return substr(line, i)
        }

        if (next_col == count) {
            return substr(line, i + 1)
        }
        if (next_col > count) {
            rest = ""
            while (count < next_col) {
                rest = rest " "
                count++
            }
            return rest substr(line, i + 1)
        }

        col = next_col
    }
    return ""
}

function repeat_spaces(count,    text) {
    text = ""
    while (count > 0) {
        text = text " "
        count--
    }
    return text
}

function expand_tabs_from(line, start_col,    i, col, ch, next_col, text) {
    col = start_col
    text = ""
    for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (ch == "\t") {
            next_col = col + 4 - (col % 4)
            text = text repeat_spaces(next_col - col)
            col = next_col
        } else {
            text = text ch
            col++
        }
    }
    return text
}

function strip_indent_from(line, count, start_col,    i, col, ch, next_col, target_col) {
    target_col = start_col + count
    col = start_col

    for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1)

        if (ch == " ") {
            next_col = col + 1
        } else if (ch == "\t") {
            next_col = col + 4 - (col % 4)
        } else {
            return expand_tabs_from(substr(line, i), col)
        }

        if (next_col == target_col) {
            return expand_tabs_from(substr(line, i + 1), next_col)
        }
        if (next_col > target_col) {
            return repeat_spaces(next_col - target_col) expand_tabs_from(substr(line, i + 1), next_col)
        }

        col = next_col
    }

    return ""
}
