function render_document() {
    render_children(root_node)
}

function render_children(parent,    child) {
    child = node_first_child[parent]
    while (child) {
        render_node(child)
        child = node_next[child]
    }
}

function render_node(id,    type, level, info, code_text, tag, start) {
    type = node_type[id]

    if (type == "paragraph") {
        print "<p>" render_inlines(node_literal[id]) "</p>"
    } else if (type == "heading") {
        level = node_attr_value(id, "level")
        print "<h" level ">" render_inlines(node_literal[id]) "</h" level ">"
    } else if (type == "thematic_break") {
        print "<hr />"
    } else if (type == "code_block") {
        info = node_attr_value(id, "info")
        if (node_attr_value(id, "fenced")) {
            code_text = node_literal[id]
        } else {
            code_text = strip_trailing_blank_code_lines(node_literal[id])
        }
        if (code_text != "" || node_has_literal[id]) {
            code_text = code_text "\n"
        }
        if (info != "") {
            split(info, info_words, /[ \t]+/)
            print "<pre><code class=\"language-" html_attr_escape(decode_character_references_string(unescape_backslash_punctuation(info_words[1]))) "\">" html_escape(code_text) "</code></pre>"
        } else {
            print "<pre><code>" html_escape(code_text) "</code></pre>"
        }
    } else if (type == "html_block") {
        print node_literal[id]
    } else if (type == "list") {
        tag = "ul"
        if (node_attr_value(id, "list_type") == "ordered") {
            tag = "ol"
        }
        start = node_attr_value(id, "start")
        if (tag == "ol" && start != "" && start != 1) {
            print "<" tag " start=\"" start "\">"
        } else {
            print "<" tag ">"
        }
        render_children(id)
        print "</" tag ">"
    } else if (type == "list_item") {
        printf "<li>"
        render_list_item_children(id)
        print "</li>"
    } else if (type == "block_quote") {
        print "<blockquote>"
        render_children(id)
        print "</blockquote>"
    }
}

function strip_trailing_blank_code_lines(text) {
    while (text ~ /\n$/) {
        text = substr(text, 1, length(text) - 1)
    }
    return text
}

function render_list_item_children(parent,    child, list, loose) {
    list = node_parent[parent]
    loose = node_attr_value(list, "loose")
    child = node_first_child[parent]
    while (child) {
        if (node_type[child] == "paragraph") {
            if (loose) {
                printf "<p>%s</p>", render_inlines(node_literal[child])
            } else {
                printf "%s", render_inlines(node_literal[child])
            }
        } else {
            render_node(child)
        }
        child = node_next[child]
    }
}
