function render_inlines(text) {
    inlines_init()
    inline_depth = 0
    inline_token_count = 0
    return render_inline_text(text)
}

function inlines_init() {
    if (inlines_initialized) {
        return
    }

    init_named_entities()
    init_autolink_href_escapes()
    inlines_initialized = 1
}

function init_named_entities() {
    named_entity["amp;"] = "&"
    named_entity["lt;"] = "<"
    named_entity["gt;"] = ">"
    named_entity["quot;"] = "\""
    named_entity["apos;"] = "'"
    named_entity["nbsp;"] = " "
    named_entity["copy;"] = "©"
    named_entity["reg;"] = "®"
    named_entity["trade;"] = "™"
    named_entity["mdash;"] = "—"
    named_entity["ndash;"] = "–"
    named_entity["hellip;"] = "…"
    named_entity["lsquo;"] = "‘"
    named_entity["rsquo;"] = "’"
    named_entity["ldquo;"] = "“"
    named_entity["rdquo;"] = "”"
    named_entity["laquo;"] = "«"
    named_entity["raquo;"] = "»"
    named_entity["euro;"] = "€"
    named_entity["pound;"] = "£"
    named_entity["yen;"] = "¥"
    named_entity["cent;"] = "¢"
    named_entity["plusmn;"] = "±"
    named_entity["times;"] = "×"
    named_entity["divide;"] = "÷"
    named_entity["ne;"] = "≠"
    named_entity["le;"] = "≤"
    named_entity["ge;"] = "≥"
    named_entity["deg;"] = "°"
    named_entity["AElig;"] = "Æ"
    named_entity["Dcaron;"] = "Ď"
    named_entity["frac34;"] = "¾"
    named_entity["HilbertSpace;"] = "ℋ"
    named_entity["DifferentialD;"] = "ⅆ"
    named_entity["ClockwiseContourIntegral;"] = "∲"
    named_entity["ngE;"] = "≧̸"
    named_entity["ouml;"] = "ö"
    named_entity["auml;"] = "ä"
}

function init_autolink_href_escapes() {
    autolink_href_escape["\\"] = "%5C"
    autolink_href_escape["`"] = "%60"
    autolink_href_escape["["] = "%5B"
    autolink_href_escape["]"] = "%5D"
}

function render_inline_text(text,    out) {
    inline_depth++
    out = render_emphasis_text(render_inline_base(text))
    inline_depth--
    if (inline_depth == 0) {
        out = restore_inline_tokens(out)
    }
    return out
}

function protect_inline_html(html,    id, marker) {
    id = ++inline_token_count
    inline_token_html[id] = html
    marker = inline_token_marker(id)
    return marker
}

function inline_token_marker(id) {
    return sprintf("%c", 28) id sprintf("%c", 28)
}

function restore_inline_tokens(text,    out, i, ch, token_end, id) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == sprintf("%c", 28)) {
            token_end = find_sequence(text, i + 1, sprintf("%c", 28))
            id = substr(text, i + 1, token_end - i - 1) + 0
            out = out restore_inline_tokens(inline_token_html[id])
            i = token_end
        } else {
            out = out ch
        }
    }
    return out
}

function html_escape_numeric(ch) {
    if (ch == "*") {
        return "&#42;"
    }
    if (ch == "_") {
        return "&#95;"
    }
    return html_escape(ch)
}

function render_emphasis_text(text,    i, ch, run_len, prev_ch, next_ch, left, right, can_open, can_close, id, closer, opener, use_len) {
    emphasis_reset()

    i = 1
    while (i <= length(text)) {
        ch = substr(text, i, 1)
        if (ch == sprintf("%c", 28)) {
            i = find_sequence(text, i + 1, sprintf("%c", 28)) + 1
            continue
        }
        if (ch == "*" || ch == "_") {
            run_len = marker_run_length(text, i, ch)
            prev_ch = emphasis_prev_char(text, i)
            next_ch = emphasis_next_char(text, i + run_len)
            left = emphasis_left_flanking(prev_ch, next_ch)
            right = emphasis_right_flanking(prev_ch, next_ch)
            if (ch == "*") {
                can_open = left
                can_close = right
            } else {
                can_open = left && (!right || emphasis_is_punctuation(prev_ch))
                can_close = right && (!left || emphasis_is_punctuation(next_ch))
            }

            id = ++emph_count
            emph_pos[id] = i
            emph_len[id] = run_len
            emph_char[id] = ch
            emph_can_open[id] = can_open
            emph_can_close[id] = can_close
            emph_open_left[id] = run_len
            emph_close_left[id] = run_len
            emph_open_tags[id] = ""
            emph_close_tags[id] = ""
            i += run_len
        } else {
            i++
        }
    }

    for (closer = 1; closer <= emph_count; closer++) {
        while (emph_can_close[closer] && emph_close_left[closer] > 0) {
            opener = find_emphasis_opener(closer)
            if (!opener) {
                break
            }
            use_len = 1
            if (emph_open_left[opener] >= 2 && emph_close_left[closer] >= 2) {
                use_len = 2
            }
            emph_open_left[opener] -= use_len
            emph_close_left[closer] -= use_len
            if (use_len == 2) {
                emph_open_tags[opener] = "<strong>" emph_open_tags[opener]
                emph_close_tags[closer] = emph_close_tags[closer] "</strong>"
            } else {
                emph_open_tags[opener] = "<em>" emph_open_tags[opener]
                emph_close_tags[closer] = emph_close_tags[closer] "</em>"
            }
            emphasis_deactivate_inner_openers(opener, closer)
        }
    }

    return render_emphasis_result(text)
}

function emphasis_reset(    i) {
    for (i = 1; i <= emph_count; i++) {
        emph_pos[i] = ""
        emph_len[i] = ""
        emph_char[i] = ""
        emph_can_open[i] = ""
        emph_can_close[i] = ""
        emph_open_left[i] = ""
        emph_close_left[i] = ""
        emph_open_tags[i] = ""
        emph_close_tags[i] = ""
    }
    emph_count = 0
}

function find_emphasis_opener(closer,    opener) {
    for (opener = closer - 1; opener >= 1; opener--) {
        if (!emph_can_open[opener] || emph_open_left[opener] <= 0) {
            continue
        }
        if (emph_char[opener] != emph_char[closer]) {
            continue
        }
        if (emphasis_rule_of_three_blocks(opener, closer)) {
            continue
        }
        return opener
    }
    return 0
}

function emphasis_deactivate_inner_openers(opener, closer,    i) {
    for (i = opener + 1; i < closer; i++) {
        if (emph_open_left[i] > 0) {
            emph_can_open[i] = 0
        }
    }
}

function emphasis_rule_of_three_blocks(opener, closer,    sum) {
    if (!(emph_can_close[opener] || emph_can_open[closer])) {
        return 0
    }
    sum = emph_len[opener] + emph_len[closer]
    return (sum % 3 == 0) && (emph_len[opener] % 3 != 0 || emph_len[closer] % 3 != 0)
}

function render_emphasis_result(text,    out, i, id, ch, lit, token_end) {
    out = ""
    id = 1
    i = 1
    while (i <= length(text)) {
        if (id <= emph_count && i == emph_pos[id]) {
            lit = emph_open_left[id] + emph_close_left[id] - emph_len[id]
            if (lit < 0) {
                lit = 0
            }
            if (emph_close_tags[id] != "") {
                out = out emph_close_tags[id]
            }
            while (lit > 0) {
                out = out html_escape(emph_char[id])
                lit--
            }
            if (emph_open_tags[id] != "") {
                out = out emph_open_tags[id]
            }
            i += emph_len[id]
            id++
            continue
        }

        ch = substr(text, i, 1)
        if (ch == sprintf("%c", 28)) {
            token_end = find_sequence(text, i + 1, sprintf("%c", 28))
            out = out substr(text, i, token_end - i + 1)
            i = token_end + 1
        } else {
            out = out ch
            i++
        }
    }
    return out
}

function emphasis_prev_char(text, pos,    i, ch) {
    i = pos - 1
    if (i < 1) {
        return ""
    }
    if (!awk_has_unicode_chars()) {
        while (i > 1 && is_utf8_continuation_byte(substr(text, i, 1))) {
            i--
        }
        return substr(text, i, pos - i)
    }
    ch = substr(text, i, 1)
    if (ch == sprintf("%c", 28)) {
        return "x"
    }
    return ch
}

function emphasis_next_char(text, pos,    ch, end) {
    if (pos > length(text)) {
        return ""
    }
    if (!awk_has_unicode_chars()) {
        return utf8_char_at(text, pos)
    }
    ch = substr(text, pos, 1)
    if (ch == sprintf("%c", 28)) {
        return "x"
    }
    return ch
}

function emphasis_left_flanking(prev_ch, next_ch) {
    return !emphasis_is_space(next_ch) && next_ch != "" && (!emphasis_is_punctuation(next_ch) || emphasis_is_space(prev_ch) || prev_ch == "" || emphasis_is_punctuation(prev_ch))
}

function emphasis_right_flanking(prev_ch, next_ch) {
    return !emphasis_is_space(prev_ch) && prev_ch != "" && (!emphasis_is_punctuation(prev_ch) || emphasis_is_space(next_ch) || next_ch == "" || emphasis_is_punctuation(next_ch))
}

function emphasis_is_space(ch) {
    return ch == "" || ch == " " || ch == "\t" || ch == "\n" || ch == "\r" || is_unicode_space_separator(ch)
}

function is_unicode_space_separator(ch,    codepoint) {
    if (is_ascii_character(ch)) {
        return 0
    }
    codepoint = unicode_codepoint(ch)
    return codepoint == 160 || codepoint == 5760 || (codepoint >= 8192 && codepoint <= 8202) || codepoint == 8239 || codepoint == 8287 || codepoint == 12288
}

function emphasis_is_punctuation(ch) {
    if (ch == "" || emphasis_is_space(ch)) {
        return 0
    }
    if (!is_ascii_string(ch)) {
        return unicode_is_punctuation_or_symbol(ch)
    }
    return ch !~ /^[[:alnum:]]$/
}

function unicode_is_punctuation_or_symbol(ch,    codepoint) {
    codepoint = unicode_codepoint(ch)
    return codepoint == 163 || codepoint == 165 || codepoint == 167 || codepoint == 169 || codepoint == 171 || codepoint == 172 || codepoint == 174 || codepoint == 176 || codepoint == 177 || codepoint == 182 || codepoint == 183 || codepoint == 187 || codepoint == 191 || (codepoint >= 8208 && codepoint <= 8292) || (codepoint >= 8352 && codepoint <= 8399) || codepoint == 123647
}

function render_inline_base(text,    out, i, ch, next_ch, prev_ch, closer, content, html_end, spaces, j, saved_label, saved_dest, saved_title, saved_end, html) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        prev_ch = substr(text, i - 1, 1)

        if (ch == "&" && parse_character_reference(text, i)) {
            out = out html_escape_numeric(char_ref_text)
            i = char_ref_end
        } else if (ch == "!" && next_ch == "[") {
            if (parse_image(text, i)) {
                saved_label = image_label
                saved_dest = image_src
                saved_title = image_title
                saved_end = image_end
                html = "<img src=\"" html_attr_escape(saved_dest) "\" alt=\"" html_attr_escape(render_alt_text(saved_label)) "\""
                if (saved_title != "") {
                    html = html " title=\"" html_attr_escape(saved_title) "\""
                }
                html = html ">"
                out = out protect_inline_html(html)
                i = saved_end
            } else {
                out = out html_escape(ch)
            }
        } else if (ch == "[") {
            if (parse_inline_link(text, i)) {
                saved_label = link_label
                saved_dest = link_dest
                saved_title = link_title
                saved_end = link_end
                html = "<a href=\"" html_attr_escape(saved_dest) "\""
                if (saved_title != "") {
                    html = html " title=\"" html_attr_escape(saved_title) "\""
                }
                html = html ">" render_inline_text(saved_label) "</a>"
                out = out protect_inline_html(html)
                i = saved_end
            } else if (parse_reference_link(text, i)) {
                saved_label = link_label
                saved_dest = link_dest
                saved_title = link_title
                saved_end = link_end
                html = "<a href=\"" html_attr_escape(saved_dest) "\""
                if (saved_title != "") {
                    html = html " title=\"" html_attr_escape(saved_title) "\""
                }
                html = html ">" render_inline_text(saved_label) "</a>"
                out = out protect_inline_html(html)
                i = saved_end
            } else {
                out = out html_escape(ch)
            }
        } else if (ch == "\\" && next_ch == "\n") {
            out = out "<br>"
            i += 1
            while (substr(text, i + 1, 1) == " " || substr(text, i + 1, 1) == "\t") {
                i++
            }
        } else if (ch == " ") {
            spaces = 1
            j = i + 1
            while (substr(text, j, 1) == " ") {
                spaces++
                j++
            }
            if (spaces >= 2 && substr(text, j, 1) == "\n") {
                out = out "<br>"
                i = j
                while (substr(text, i + 1, 1) == " " || substr(text, i + 1, 1) == "\t") {
                    i++
                }
            } else {
                out = out ch
            }
        } else if (ch == "<") {
            if (substr(text, i, 4) == "<!--") {
                html_end = find_sequence(text, i + 4, "-->")
                if (html_end) {
                    if (substr(text, i, 5) == "<!-->") {
                        out = out protect_inline_html("<!-->" html_escape(substr(text, i + 5, html_end - i - 2)))
                    } else if (substr(text, i, 6) == "<!--->") {
                        out = out protect_inline_html("<!--->" html_escape(substr(text, i + 6, html_end - i - 3)))
                    } else {
                        out = out protect_inline_html(substr(text, i, html_end - i + 3))
                    }
                    i = html_end + 2
                    continue
                }
            } else if (substr(text, i, 2) == "<?") {
                html_end = find_sequence(text, i + 2, "?>")
                if (html_end) {
                    out = out protect_inline_html(substr(text, i, html_end - i + 2))
                    i = html_end + 1
                    continue
                }
            } else if (substr(text, i, 9) == "<![CDATA[") {
                html_end = find_sequence(text, i + 9, "]]>")
                if (html_end) {
                    out = out protect_inline_html(substr(text, i, html_end - i + 3))
                    i = html_end + 2
                    continue
                }
            } else if (substr(text, i, 2) == "<!" && substr(text, i + 2, 1) ~ /^[A-Z]$/) {
                html_end = find_angle_end(text, i + 2)
                if (html_end) {
                    out = out protect_inline_html(substr(text, i, html_end - i + 1))
                    i = html_end
                    continue
                }
            }

            html_end = find_html_tag_end(text, i + 1)
            if (html_end) {
                content = substr(text, i + 1, html_end - i - 1)
                if (is_uri_autolink(content)) {
                    out = out protect_inline_html("<a href=\"" html_attr_escape(uri_autolink_href(content)) "\">" html_escape(content) "</a>")
                    i = html_end
                } else if (is_email_autolink(content)) {
                    out = out protect_inline_html("<a href=\"mailto:" html_attr_escape(content) "\">" html_escape(content) "</a>")
                    i = html_end
                } else if (is_raw_html_inline(content)) {
                    out = out protect_inline_html("<" content ">")
                    i = html_end
                } else {
                    out = out html_escape(ch)
                }
            } else {
                out = out html_escape(ch)
            }
        } else if (ch == "`") {
            closer = find_code_span_closer(text, i)
            if (closer) {
                content = substr(text, i + code_span_len, closer - i - code_span_len)
                out = out protect_inline_html("<code>" html_escape(normalize_code_span(content)) "</code>")
                i = closer + code_span_len - 1
            } else {
                out = out html_escape(substr(text, i, code_span_len))
                i += code_span_len - 1
            }
        } else if (ch == "\\" && is_ascii_punctuation(next_ch)) {
            out = out html_escape_numeric(next_ch)
            i++
        } else if (ch == "*" || ch == "_") {
            out = out ch
        } else {
            out = out html_escape(ch)
        }
    }
    return out
}

function parse_image(text, start) {
    if (substr(text, start, 2) != "![") {
        return 0
    }
    allow_nested_link_label++
    if (parse_inline_link(text, start + 1) || parse_reference_link(text, start + 1)) {
        allow_nested_link_label--
        image_label = link_label
        image_src = link_dest
        image_title = link_title
        image_end = link_end
        return 1
    }
    allow_nested_link_label--
    return 0
}

function render_alt_text(text,    out, i, ch, next_ch, closer, content, saved_label, saved_end) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (ch == "!" && next_ch == "[" && parse_image(text, i)) {
            saved_label = image_label
            saved_end = image_end
            out = out render_alt_text(saved_label)
            i = saved_end
        } else if (ch == "[" && substr(text, i - 1, 1) != "!" && (parse_inline_link(text, i) || parse_reference_link(text, i))) {
            saved_label = link_label
            saved_end = link_end
            out = out render_alt_text(saved_label)
            i = saved_end
        } else if (ch == "`") {
            closer = find_code_span_closer(text, i)
            if (closer) {
                content = substr(text, i + code_span_len, closer - i - code_span_len)
                out = out normalize_code_span(content)
                i = closer + code_span_len - 1
            } else {
                out = out ch
            }
        } else if (ch == "*") {
            closer = find_emphasis_closer(text, i + 1, "*")
            if (closer) {
                content = substr(text, i + 1, closer - i - 1)
                out = out render_alt_text(content)
                i = closer
            } else {
                out = out ch
            }
        } else if (ch == "\\" && is_ascii_punctuation(next_ch)) {
            out = out next_ch
            i++
        } else if (ch == "&" && parse_character_reference(text, i)) {
            out = out char_ref_text
            i = char_ref_end
        } else if (ch == "<") {
            out = out ch
        } else {
            out = out ch
        }
    }
    return out
}

function parse_reference_link(text, start,    close_idx, next_ch, ref_close, label, ref_label, key) {
    close_idx = find_link_label_end(text, start + 1)
    if (!close_idx) {
        return 0
    }

    label = substr(text, start + 1, close_idx - start - 1)
    if (!allow_nested_link_label && label_contains_link(label)) {
        return 0
    }
    next_ch = substr(text, close_idx + 1, 1)

    if (next_ch == "[") {
        ref_close = find_link_label_end(text, close_idx + 2)
        if (!ref_close) {
            return 0
        }
        ref_label = substr(text, close_idx + 2, ref_close - close_idx - 2)
        if (ref_label == "") {
            ref_label = label
        }
        link_end = ref_close
    } else {
        ref_label = label
        link_end = close_idx
    }

    if (label_has_unescaped_bracket(ref_label)) {
        return 0
    }

    key = normalize_reference_label(ref_label)
    if (!(key in ref_dest)) {
        return 0
    }

    link_label = label
    link_dest = ref_dest[key]
    link_title = ref_title[key]
    return 1
}

function normalize_reference_label(text,    out) {
    out = unescape_reference_label_brackets(text)
    gsub(/[\t\r\n ]+/, " ", out)
    out = trim(out)
    out = unicode_case_fold(out)
    gsub(/ẞ/, "ss", out)
    gsub(/ß/, "ss", out)
    return tolower(out)
}

function unicode_case_fold(text) {
    gsub(/Α/, "α", text)
    gsub(/Β/, "β", text)
    gsub(/Γ/, "γ", text)
    gsub(/Δ/, "δ", text)
    gsub(/Ε/, "ε", text)
    gsub(/Ζ/, "ζ", text)
    gsub(/Η/, "η", text)
    gsub(/Θ/, "θ", text)
    gsub(/Ι/, "ι", text)
    gsub(/Κ/, "κ", text)
    gsub(/Λ/, "λ", text)
    gsub(/Μ/, "μ", text)
    gsub(/Ν/, "ν", text)
    gsub(/Ξ/, "ξ", text)
    gsub(/Ο/, "ο", text)
    gsub(/Π/, "π", text)
    gsub(/Ρ/, "ρ", text)
    gsub(/Σ/, "σ", text)
    gsub(/Τ/, "τ", text)
    gsub(/Υ/, "υ", text)
    gsub(/Φ/, "φ", text)
    gsub(/Χ/, "χ", text)
    gsub(/Ψ/, "ψ", text)
    gsub(/Ω/, "ω", text)
    return text
}

function unescape_reference_label_brackets(text,    out, i, ch, next_ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (ch == "\\" && (next_ch == "[" || next_ch == "]")) {
            out = out next_ch
            i++
        } else {
            out = out ch
        }
    }
    return out
}

function label_has_unescaped_bracket(text,    i, ch) {
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            i++
        } else if (ch == "[" || ch == "]") {
            return 1
        }
    }
    return 0
}

function parse_character_reference(text, start,    end, ref) {
    char_ref_text = ""
    char_ref_end = start

    end = find_character_reference_end(text, start)
    if (!end) {
        return 0
    }

    ref = substr(text, start, end - start + 1)
    if (!decode_character_reference(ref)) {
        return 0
    }

    char_ref_end = end
    return 1
}

function find_character_reference_end(text, start,    i, ch, max_len) {
    max_len = 32
    for (i = start + 1; i <= length(text) && i <= start + max_len; i++) {
        ch = substr(text, i, 1)
        if (ch == ";") {
            return i
        }
        if (ch !~ /^[A-Za-z0-9#]$/) {
            return 0
        }
    }
    return 0
}

function decode_character_references_string(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "&" && parse_character_reference(text, i)) {
            out = out char_ref_text
            i = char_ref_end
        } else {
            out = out ch
        }
    }
    return out
}

function decode_character_reference(ref,    body, codepoint, name) {
    inlines_init()
    char_ref_text = ""

    if (ref ~ /^&#[0-9]+;$/) {
        body = substr(ref, 3, length(ref) - 3)
        codepoint = parse_decimal_codepoint(body)
        if (codepoint > 1114111) {
            return 0
        }
        char_ref_text = character_from_codepoint(codepoint)
    } else if (ref ~ /^&#[xX][0-9A-Fa-f]+;$/) {
        body = substr(ref, 4, length(ref) - 4)
        codepoint = parse_hex_codepoint(body)
        if (codepoint > 1114111) {
            return 0
        }
        char_ref_text = character_from_codepoint(codepoint)
    } else {
        name = substr(ref, 2)
        if (!(name in named_entity)) {
            return 0
        }
        char_ref_text = named_entity[name]
    }

    return 1
}

function parse_decimal_codepoint(text,    i, value, digit) {
    value = 0
    for (i = 1; i <= length(text); i++) {
        digit = substr(text, i, 1) + 0
        value = (value * 10) + digit
    }
    return value
}

function parse_hex_codepoint(text,    i, value) {
    value = 0
    for (i = 1; i <= length(text); i++) {
        value = (value * 16) + hex_digit_value(substr(text, i, 1))
    }
    return value
}

function hex_digit_value(ch) {
    if (ch >= "0" && ch <= "9") {
        return ch + 0
    }
    if (ch >= "a" && ch <= "f") {
        return index("abcdef", ch) + 9
    }
    return index("ABCDEF", ch) + 9
}

function character_from_codepoint(codepoint) {
    if (codepoint == 0 || (codepoint >= 55296 && codepoint <= 57343)) {
        return "�"
    }
    if (!awk_has_unicode_chars()) {
        return utf8_from_codepoint(codepoint)
    }
    return sprintf("%c", codepoint)
}

function find_angle_end(text, start,    i, ch) {
    for (i = start; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == ">") {
            return i
        }
    }
    return 0
}

function find_html_tag_end(text, start,    i, ch, quote) {
    quote = ""
    for (i = start; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (ch == ">") {
            return i
        }
    }
    return 0
}

function find_sequence(text, start, sequence,    i, n) {
    n = length(sequence)
    for (i = start; i <= length(text) - n + 1; i++) {
        if (substr(text, i, n) == sequence) {
            return i
        }
    }
    return 0
}

function is_uri_autolink(text) {
    return text ~ /^[A-Za-z][A-Za-z0-9.+-]{1,31}:[^ <>]*$/
}

function is_email_autolink(text,    at, local, domain, labels, count, i) {
    at = index(text, "@")
    if (at <= 1 || at != find_last_char(text, "@")) {
        return 0
    }

    local = substr(text, 1, at - 1)
    domain = substr(text, at + 1)
    if (!is_email_local_part(local)) {
        return 0
    }

    count = split(domain, labels, /\./)
    if (count < 2) {
        return 0
    }
    for (i = 1; i <= count; i++) {
        if (!is_email_domain_label(labels[i])) {
            return 0
        }
    }
    return 1
}

function find_last_char(text, needle,    i, found) {
    found = 0
    for (i = 1; i <= length(text); i++) {
        if (substr(text, i, 1) == needle) {
            found = i
        }
    }
    return found
}

function is_email_local_part(text,    i, ch) {
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch !~ /^[A-Za-z0-9]$/ && index(".!#$%&'*+/=?^_`{|}~-", ch) == 0) {
            return 0
        }
    }
    return length(text) > 0
}

function is_email_domain_label(text) {
    if (text == "" || substr(text, 1, 1) == "-" || substr(text, length(text), 1) == "-") {
        return 0
    }
    return text ~ /^[A-Za-z0-9-]+$/
}

function is_raw_html_inline(text,    pos, len, ch, name, had_space) {
    len = length(text)
    pos = 1

    if (substr(text, pos, 1) == "/") {
        pos++
        if (!parse_html_name(text, pos, 1)) {
            return 0
        }
        pos = html_name_end
        pos = skip_inline_html_space(text, pos)
        return pos > len
    }

    if (!parse_html_name(text, pos, 1)) {
        return 0
    }
    pos = html_name_end

    while (pos <= len) {
        had_space = 0
        while (substr(text, pos, 1) == " " || substr(text, pos, 1) == "\t" || substr(text, pos, 1) == "\n") {
            had_space = 1
            pos++
        }
        if (pos > len) {
            return 1
        }
        if (substr(text, pos, 1) == "/" && pos == len) {
            return 1
        }
        if (!had_space || !parse_html_attribute(text, pos)) {
            return 0
        }
        pos = html_attr_end
    }
    return 1
}

function parse_html_name(text, pos, tag_name,    ch) {
    ch = substr(text, pos, 1)
    if (tag_name) {
        if (ch !~ /^[A-Za-z]$/) {
            return 0
        }
        pos++
        while (substr(text, pos, 1) ~ /^[A-Za-z0-9-]$/) {
            pos++
        }
    } else {
        if (ch !~ /^[A-Za-z_:]$/) {
            return 0
        }
        pos++
        while (substr(text, pos, 1) ~ /^[A-Za-z0-9_.:-]$/) {
            pos++
        }
    }
    html_name_end = pos
    return 1
}

function parse_html_attribute(text, pos,    len, ch, quote, after_name) {
    len = length(text)
    if (!parse_html_name(text, pos, 0)) {
        return 0
    }
    pos = html_name_end
    after_name = pos
    pos = skip_inline_html_space(text, pos)
    if (substr(text, pos, 1) != "=") {
        html_attr_end = after_name
        return 1
    }

    pos++
    pos = skip_inline_html_space(text, pos)
    quote = substr(text, pos, 1)
    if (quote == "\"" || quote == "'") {
        pos++
        while (pos <= len && substr(text, pos, 1) != quote) {
            pos++
        }
        if (pos > len) {
            return 0
        }
        pos++
    } else {
        if (pos > len) {
            return 0
        }
        while (pos <= len) {
            ch = substr(text, pos, 1)
            if (ch == " " || ch == "\t" || ch == "\n") {
                break
            }
            if (ch == "\"" || ch == "'" || ch == "=" || ch == "<" || ch == ">" || ch == "`") {
                return 0
            }
            pos++
        }
    }
    html_attr_end = pos
    return 1
}

function skip_inline_html_space(text, pos) {
    while (substr(text, pos, 1) == " " || substr(text, pos, 1) == "\t" || substr(text, pos, 1) == "\n") {
        pos++
    }
    return pos
}

function uri_autolink_href(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch in autolink_href_escape) {
            out = out autolink_href_escape[ch]
        } else {
            out = out ch
        }
    }
    return out
}

function parse_inline_link(text, start,    close_idx, open_paren, i, depth, ch, inside, dest, title, in_angle) {
    close_idx = find_link_label_end(text, start + 1)
    if (!close_idx || substr(text, close_idx + 1, 1) != "(") {
        return 0
    }
    link_label = substr(text, start + 1, close_idx - start - 1)
    if (!allow_nested_link_label && label_contains_link(link_label)) {
        return 0
    }

    open_paren = close_idx + 1
    depth = 0
    in_angle = 0
    for (i = open_paren + 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (in_angle) {
            if (ch == "\\") {
                i++
            } else if (ch == ">") {
                in_angle = 0
            } else if (ch == "\n") {
                return 0
            }
        } else if (ch == "\\") {
            i++
        } else if (ch == "<") {
            in_angle = 1
        } else if (ch == "(") {
            depth++
        } else if (ch == ")") {
            if (depth == 0) {
                inside = trim(substr(text, open_paren + 1, i - open_paren - 1))
                if (parse_link_destination_title(inside)) {
                    if (has_unbalanced_backticks(link_label)) {
                        return 0
                    }
                    link_end = i
                    return 1
                }
                return 0
            }
            depth--
        }
    }
    return 0
}

function find_link_label_end(text, start,    i, ch, depth, closer, html_end) {
    depth = 0
    for (i = start; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            i++
        } else if (ch == "`") {
            closer = find_code_span_closer(text, i)
            if (closer) {
                i = closer + code_span_len - 1
            }
        } else if (ch == "<") {
            html_end = find_html_tag_end(text, i + 1)
            if (html_end) {
                i = html_end
            }
        } else if (ch == "[") {
            depth++
        } else if (ch == "]") {
            if (depth == 0) {
                return i
            }
            depth--
        } else if (ch == "\n") {
            return 0
        }
    }
    return 0
}

function label_contains_link(text,    i, ch, saved_allow) {
    saved_allow = allow_nested_link_label
    allow_nested_link_label = 1
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            i++
        } else if (ch == "[" && substr(text, i - 1, 1) != "!" && (parse_inline_link(text, i) || parse_reference_link(text, i))) {
            allow_nested_link_label = saved_allow
            return 1
        }
    }
    allow_nested_link_label = saved_allow
    return 0
}

function parse_link_destination_title(text,    rest, q, endq) {
    link_dest = ""
    link_title = ""
    rest = trim(text)

    if (substr(rest, 1, 1) == "<") {
        endq = find_link_angle_destination_end(rest)
        if (!endq) {
            return 0
        }
        link_dest = substr(rest, 2, endq - 2)
        rest = trim(substr(rest, endq + 1))
    } else {
        link_dest = rest
        sub(/[ \t\n].*$/, "", link_dest)
        rest = trim(substr(rest, length(link_dest) + 1))
    }

    link_dest = link_href_escape(decode_character_references_string(unescape_backslash_punctuation(link_dest)))

    if (rest == "") {
        return 1
    }

    q = substr(rest, 1, 1)
    if (q == "\"" || q == "'") {
        endq = find_link_title_end(rest, 1, q)
        if (!endq || trim(substr(rest, endq + 1)) != "") {
            return 0
        }
        link_title = decode_character_references_string(unescape_backslash_punctuation(substr(rest, 2, endq - 2)))
        return 1
    }

    if (q == "(" && substr(rest, length(rest), 1) == ")") {
        link_title = decode_character_references_string(unescape_backslash_punctuation(substr(rest, 2, length(rest) - 2)))
        return 1
    }

    return 0
}

function find_link_title_end(text, start, quote,    i, ch) {
    for (i = start + 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            i++
        } else if (ch == quote) {
            return i
        }
    }
    return 0
}

function find_link_angle_destination_end(text,    i, ch) {
    for (i = 2; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            i++
        } else if (ch == "\n") {
            return 0
        } else if (ch == ">") {
            return i
        }
    }
    return 0
}

function has_unbalanced_backticks(text,    i, count) {
    count = 0
    for (i = 1; i <= length(text); i++) {
        if (substr(text, i, 1) == "`") {
            count++
        }
    }
    return count % 2
}

function unescape_backslash_punctuation(text,    out, i, ch, next_ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (ch == "\\" && is_ascii_punctuation(next_ch)) {
            out = out next_ch
            i++
        } else {
            out = out ch
        }
    }
    return out
}

function link_href_escape(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == " ") {
            out = out "%20"
        } else if (ch == "\"") {
            out = out "%22"
        } else if (ch == "\\") {
            out = out "%5C"
        } else if (!is_ascii_character(ch)) {
            out = out utf8_percent_encode(ch)
        } else {
            out = out ch
        }
    }
    return out
}

function is_ascii_character(ch,    i) {
    if (!ascii_character_cache_ready) {
        for (i = 1; i < 128; i++) {
            ascii_character_cache[sprintf("%c", i)] = 1
        }
        ascii_character_cache_ready = 1
    }
    return ch in ascii_character_cache
}

function utf8_percent_encode(ch,    codepoint, out, b1, b2, b3, b4) {
    if (!awk_has_unicode_chars()) {
        return sprintf("%%%02X", byte_value(ch))
    }

    codepoint = unicode_codepoint(ch)
    if (codepoint < 0) {
        return ch
    }
    if (codepoint < 128) {
        return sprintf("%%%02X", codepoint)
    }
    if (codepoint < 2048) {
        b1 = 192 + int(codepoint / 64)
        b2 = 128 + (codepoint % 64)
        return sprintf("%%%02X%%%02X", b1, b2)
    }
    if (codepoint < 65536) {
        b1 = 224 + int(codepoint / 4096)
        b2 = 128 + (int(codepoint / 64) % 64)
        b3 = 128 + (codepoint % 64)
        return sprintf("%%%02X%%%02X%%%02X", b1, b2, b3)
    }

    b1 = 240 + int(codepoint / 262144)
    b2 = 128 + (int(codepoint / 4096) % 64)
    b3 = 128 + (int(codepoint / 64) % 64)
    b4 = 128 + (codepoint % 64)
    return sprintf("%%%02X%%%02X%%%02X%%%02X", b1, b2, b3, b4)
}

function unicode_codepoint(ch,    codepoint, low, high, mid, candidate) {
    if (ch in unicode_codepoint_cache) {
        return unicode_codepoint_cache[ch]
    }

    if (!awk_has_unicode_chars()) {
        codepoint = utf8_sequence_codepoint(ch)
        unicode_codepoint_cache[ch] = codepoint
        return codepoint
    }

    low = 128
    high = 1114111
    while (low <= high) {
        mid = int((low + high) / 2)
        candidate = sprintf("%c", mid)
        if (candidate == ch) {
            unicode_codepoint_cache[ch] = mid
            return mid
        }
        if (candidate < ch) {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }

    unicode_codepoint_cache[ch] = -1
    return -1
}

function awk_has_unicode_chars() {
    if (!awk_unicode_mode_checked) {
        awk_unicode_mode = (length("ö") == 1)
        awk_unicode_mode_checked = 1
    }
    return awk_unicode_mode
}

function is_ascii_string(text,    i) {
    for (i = 1; i <= length(text); i++) {
        if (!is_ascii_character(substr(text, i, 1))) {
            return 0
        }
    }
    return 1
}

function byte_value(ch,    i) {
    if (ch in byte_value_cache) {
        return byte_value_cache[ch]
    }
    for (i = 1; i <= 255; i++) {
        if (sprintf("%c", i) == ch) {
            byte_value_cache[ch] = i
            return i
        }
    }
    byte_value_cache[ch] = -1
    return -1
}

function is_utf8_continuation_byte(ch,    value) {
    value = byte_value(ch)
    return value >= 128 && value <= 191
}

function utf8_char_at(text, pos,    first, value, len) {
    first = substr(text, pos, 1)
    value = byte_value(first)
    if (value < 128 || value < 0) {
        return first
    }
    if (value < 224) {
        len = 2
    } else if (value < 240) {
        len = 3
    } else {
        len = 4
    }
    return substr(text, pos, len)
}

function utf8_sequence_codepoint(text,    b1, b2, b3, b4, len) {
    len = length(text)
    b1 = byte_value(substr(text, 1, 1))
    if (len == 1) {
        return b1
    }
    b2 = byte_value(substr(text, 2, 1))
    if (len == 2) {
        return ((b1 - 192) * 64) + (b2 - 128)
    }
    b3 = byte_value(substr(text, 3, 1))
    if (len == 3) {
        return ((b1 - 224) * 4096) + ((b2 - 128) * 64) + (b3 - 128)
    }
    b4 = byte_value(substr(text, 4, 1))
    return ((b1 - 240) * 262144) + ((b2 - 128) * 4096) + ((b3 - 128) * 64) + (b4 - 128)
}

function utf8_from_codepoint(codepoint,    b1, b2, b3, b4) {
    if (codepoint < 128) {
        return sprintf("%c", codepoint)
    }
    if (codepoint < 2048) {
        b1 = 192 + int(codepoint / 64)
        b2 = 128 + (codepoint % 64)
        return sprintf("%c%c", b1, b2)
    }
    if (codepoint < 65536) {
        b1 = 224 + int(codepoint / 4096)
        b2 = 128 + (int(codepoint / 64) % 64)
        b3 = 128 + (codepoint % 64)
        return sprintf("%c%c%c", b1, b2, b3)
    }
    b1 = 240 + int(codepoint / 262144)
    b2 = 128 + (int(codepoint / 4096) % 64)
    b3 = 128 + (int(codepoint / 64) % 64)
    b4 = 128 + (codepoint % 64)
    return sprintf("%c%c%c%c", b1, b2, b3, b4)
}

function find_code_span_closer(text, start,    i, run, len) {
    code_span_len = marker_run_length(text, start, "`")
    i = start + code_span_len
    while (i <= length(text)) {
        if (substr(text, i, 1) == "`") {
            len = marker_run_length(text, i, "`")
            if (len == code_span_len) {
                return i
            }
            i += len
        } else {
            i++
        }
    }
    return 0
}

function marker_run_length(text, start, marker,    i) {
    i = start
    while (i <= length(text) && substr(text, i, 1) == marker) {
        i++
    }
    return i - start
}

function normalize_code_span(text,    has_nonspace) {
    gsub(/\n/, " ", text)
    has_nonspace = text ~ /[^ ]/
    if (has_nonspace && length(text) >= 2 && substr(text, 1, 1) == " " && substr(text, length(text), 1) == " ") {
        text = substr(text, 2, length(text) - 2)
    }
    return text
}

function is_ascii_punctuation(ch) {
    if (ch == "") {
        return 0
    }
    return index("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", ch) > 0
}

function find_emphasis_closer(text, start, marker,    i, ch, prev_ch, next_ch) {
    for (i = start; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            i++
        } else if (ch == marker && i > start) {
            prev_ch = substr(text, i - 1, 1)
            if (marker == "*" && !is_ascii_alnum(prev_ch) && is_ascii_alnum(substr(text, i + 1, 1))) {
                continue
            }
            if (marker == "_") {
                next_ch = substr(text, i + 1, 1)
                if (is_ascii_alnum(prev_ch) && is_ascii_alnum(next_ch)) {
                    continue
                }
            }
            return i
        }
    }
    return 0
}

function is_ascii_alnum(ch) {
    return ch ~ /^[A-Za-z0-9]$/
}
