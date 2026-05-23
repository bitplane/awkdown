function blocks_init() {
    ref_count = 0

    nodes_init()
    root_node = node_new("document")
    open_node = 0
    set_block_state("", "")
    fence_char = ""
    fence_len = 0
    fence_indent = 0
    reset_list_context()
    reset_blockquote_context()
}

function blocks_process_line(line) {
    if (leaf_state == "fenced_code") {
        handle_fenced_code_line(line)
        return
    }

    if (leaf_state == "indented_code") {
        if (handle_indented_code_line(line)) {
            return
        }
    }

    if (leaf_state == "html_block") {
        handle_html_block_line(line)
        return
    }

    if (leaf_state == "paragraph") {
        handle_paragraph_line(line)
        return
    }

    if (block_context == "blockquote" && leaf_state == "") {
        handle_blockquote_open_line(line)
        return
    }

    handle_top_level_line(line)
}

function handle_fenced_code_line(line) {
    if (!continue_leaf_container(line, 0)) {
        close_blockquote_and_reprocess(line)
        return
    }

    if (is_closing_fence(container_content)) {
        if (block_context == "blockquote") {
            close_open_block()
            set_block_state("blockquote", "")
        } else if (block_context == "list") {
            open_node = 0
            set_block_state("", "")
        } else {
            close_open_block()
        }
        return
    }

    node_append_literal(open_node, strip_indent(container_content, fence_indent))
}

function handle_indented_code_line(line) {
    if (block_context == "list") {
        if (is_blank(line)) {
            node_append_literal(open_node, "")
            return 1
        }
        if (leading_spaces(line) >= list_code_indent) {
            node_append_literal(open_node, strip_indent(line, list_code_indent))
            return 1
        }
        open_node = 0
        set_block_state("", "")
        blocks_process_line(line)
        return 1
    }

    if (is_blank(line)) {
        if (leading_spaces(line) >= 4) {
            node_append_literal(open_node, strip_indent(line, 4))
        } else {
            node_append_literal(open_node, "")
        }
        return 1
    }
    if (leading_spaces(line) >= 4) {
        node_append_literal(open_node, strip_indent(line, 4))
        return 1
    }
    close_open_block()
    return 0
}

function handle_html_block_line(line) {
    if (block_context == "blockquote") {
        if (is_blank(line)) {
            close_open_block()
            leave_blockquote_context()
            return
        }
        if (continue_leaf_container(line, 0)) {
            node_append_literal(open_node, container_content)
            return
        }
        close_blockquote_and_reprocess(line)
        return
    }

    if (html_block_end == "blank" && is_blank(line)) {
        close_open_block()
        return
    }
    node_append_literal(open_node, line)
    if (html_block_end != "blank" && index(tolower(line), html_block_end)) {
        close_open_block()
    }
}

function handle_paragraph_line(line) {
    if (block_context == "list") {
        handle_list_paragraph_line(line)
        return
    }
    if (block_context == "blockquote") {
        handle_blockquote_paragraph_line(line)
        return
    }
    handle_top_level_paragraph_line(line)
}

function handle_top_level_paragraph_line(line) {
    if (is_blank(line)) {
        close_open_block()
        return
    }
    if (match_setext_heading(line)) {
        extract_reference_definitions(open_node)
        if (node_type[open_node] == "reference_definition") {
            close_open_block()
            blocks_process_line(line)
            return
        }
        node_type[open_node] = "heading"
        node_set_attr(open_node, "level", matched_level)
        close_open_block()
        return
    }
    if (line_interrupts_paragraph(line)) {
        close_open_block_and_reprocess(line)
        return
    }
    if (match_list_marker(line) && list_can_interrupt_paragraph()) {
        close_open_block_and_reprocess(line)
        return
    }
    node_append_literal(open_node, line)
}

function handle_list_paragraph_line(line) {
    if (is_blank(line)) {
        close_open_block()
        pending_list_blank = 1
        return
    }
    if (current_list && leading_spaces(line) >= current_list_content_indent && match_setext_heading(strip_list_continuation(line))) {
        node_type[open_node] = "heading"
        node_set_attr(open_node, "level", matched_level)
        close_open_block()
        return
    }
    if (match_thematic_break(line)) {
        leave_list_paragraph_for_thematic_break(line)
        return
    }
    if (current_list && leading_spaces(line) == current_list_marker_indent && match_list_marker(line)) {
        start_list_item()
        return
    }
    while (current_list_depth > 1 && leading_spaces(line) < current_list_content_indent) {
        if (leading_spaces(line) == current_list_marker_indent && match_list_marker(line)) {
            break
        }
        pop_list_context()
    }
    if (current_list && leading_spaces(line) >= current_list_content_indent) {
        if (start_list_child_block(line)) {
            return
        }
    }
    if (match_list_marker(line)) {
        start_list_item()
        return
    }
    node_append_literal(open_node, strip_list_continuation(line))
}

function handle_blockquote_paragraph_line(line) {
    if (is_blank(line)) {
        close_open_block()
        leave_blockquote_paragraph()
        return
    }
    if (continue_leaf_container(line, 1)) {
        if (is_blank(container_content)) {
            close_open_block()
            set_block_state("blockquote", "")
            return
        }
        node_append_literal(open_node, container_content)
        return
    }
    if (match_thematic_break(line)) {
        close_blockquote_and_reprocess(line)
        return
    }
    if (match_opening_fence(line) || match_list_marker(line)) {
        close_open_block()
        reset_blockquote_context()
        blocks_process_line(line)
        return
    }
    node_append_literal(open_node, line)
}

function handle_blockquote_open_line(line) {
    if (is_blank(line)) {
        leave_blockquote_context()
        set_block_state("", "")
        return
    }
    if (strip_blockquote_markers(line, current_block_quote_depth)) {
        append_blockquote_content(matched_content)
        return
    }
    leave_blockquote_context()
    set_block_state("", "")
    blocks_process_line(line)
}

function handle_top_level_line(line,    html_id, para_id) {
    if (is_blank(line)) {
        if (current_list) {
            pending_list_blank = 1
        } else {
            clear_inactive_list_item()
        }
        reset_blockquote_context()
        return
    }

    if (current_list && pending_list_blank && current_list_item && !node_first_child[current_list_item] && !match_list_marker(line)) {
        reset_list_context()
    }

    while (current_list_depth > 1 && leading_spaces(line) < current_list_content_indent) {
        if (leading_spaces(line) == current_list_marker_indent && match_list_marker(line)) {
            break
        }
        pop_list_context()
    }

    if (current_list && leading_spaces(line) == current_list_marker_indent && match_list_marker(line)) {
        start_list_item()
        return
    }

    if (current_list && leading_spaces(line) >= current_list_content_indent) {
        if (start_list_child_block(line)) {
            return
        }
        start_list_continuation_paragraph(line)
        return
    }

    if (match_atx_heading(line)) {
        append_heading_block(root_node)
        return
    }

    if (match_thematic_break(line)) {
        reset_list_context()
        reset_blockquote_context()
        append_thematic_break_block(root_node)
        return
    }

    if (match_blockquote_marker(line)) {
        start_blockquote()
        return
    }

    if (match_list_marker(line)) {
        if (pending_list_blank && current_list) {
            node_set_attr(current_list, "loose", 1)
        }
        start_list_item()
        return
    }

    if (match_opening_fence(line)) {
        start_fenced_code_block(root_node, "")
        return
    }

    if (match_html_block_start(line)) {
        reset_list_context()
        html_id = start_html_block(root_node, "", line, matched_html_block_end)
        if (html_block_end != "blank" && index(tolower(line), html_block_end)) {
            close_open_block()
        }
        return
    }

    if (leading_spaces(line) >= 4) {
        start_indented_code_block(root_node, "", strip_indent(line, 4), 4)
        return
    }

    para_id = append_paragraph_block(root_node, line)
    open_node = para_id
    set_block_state("", "paragraph")
}

function blocks_finish() {
    close_open_block()
}

function close_open_block() {
    if (open_node && node_type[open_node] == "paragraph") {
        extract_reference_definitions(open_node)
    }

    open_node = 0
    set_block_state("", "")
    fence_char = ""
    fence_len = 0
    fence_indent = 0
    html_block_end = ""
}

function set_block_state(context, leaf) {
    block_context = context
    leaf_state = leaf
}

function continue_leaf_container(line, allow_partial,    content) {
    content = line
    if (current_block_quote_depth && (block_context == "blockquote" || current_list_in_blockquote)) {
        if (!(allow_partial ? strip_blockquote_markers_upto(content, current_block_quote_depth) : strip_blockquote_markers(content, current_block_quote_depth))) {
            return 0
        }
        content = matched_content
    }
    if (block_context == "list") {
        content = strip_list_continuation(content)
    }
    container_content = content
    return 1
}

function close_open_block_and_reprocess(line) {
    close_open_block()
    blocks_process_line(line)
}

function clear_inactive_list_item() {
    current_list_item = 0
    current_list_content_indent = 0
    pending_list_blank = 0
}

function leave_list_paragraph_for_thematic_break(line) {
    close_open_block()
    current_list = 0
    blocks_process_line(line)
}

function leave_blockquote_paragraph() {
    current_block_quote = 0
}

function reset_list_context() {
    current_list = 0
    current_list_item = 0
    current_list_type = ""
    current_list_marker = ""
    current_list_marker_indent = 0
    current_list_content_indent = 0
    current_list_depth = 0
    pending_list_blank = 0
    current_list_in_blockquote = 0
}

function reset_blockquote_context() {
    current_block_quote = 0
    current_block_quote_depth = 0
}

function leave_blockquote_context() {
    reset_blockquote_context()
    if (current_list_in_blockquote) {
        reset_list_context()
    }
}

function close_blockquote_and_reprocess(line) {
    close_open_block()
    leave_blockquote_context()
    blocks_process_line(line)
}

function extract_reference_definitions(id,    text, rest, key, changed) {
    text = node_literal[id]
    rest = text
    changed = 0

    while (parse_reference_definition_prefix(rest)) {
        key = normalize_reference_label(refdef_label)
        if (!(key in ref_dest)) {
            ref_dest[key] = refdef_dest
            ref_title[key] = refdef_title
            ref_keys[++ref_count] = key
        }

        rest = substr(rest, refdef_consumed + 1)
        if (substr(rest, 1, 1) == "\n") {
            rest = substr(rest, 2)
        }
        changed = 1
    }

    if (!changed) {
        return 0
    }

    if (rest == "") {
        node_type[id] = "reference_definition"
        node_literal[id] = ""
        node_has_literal[id] = 0
    } else {
        node_literal[id] = rest
        node_has_literal[id] = 1
    }
    return 1
}

function parse_reference_definition_prefix(text,    pos, len, indent, ch, escaped, label, dest_start, dest, depth, title_start, q, title, close_ch, line_rest, scan, title_on_next_line) {
    refdef_label = ""
    refdef_dest = ""
    refdef_title = ""
    refdef_consumed = 0

    len = length(text)
    pos = 1
    indent = 0
    while (pos <= len && substr(text, pos, 1) == " " && indent < 4) {
        indent++
        pos++
    }
    if (indent > 3 || substr(text, pos, 1) != "[") {
        return 0
    }

    pos++
    label = ""
    escaped = 0
    depth = 0
    while (pos <= len) {
        ch = substr(text, pos, 1)
        if (escaped) {
            label = label "\\" ch
            escaped = 0
        } else if (ch == "\\") {
            escaped = 1
        } else if (ch == "[") {
            depth++
            label = label ch
        } else if (ch == "]") {
            if (depth == 0) {
                break
            }
            depth--
            label = label ch
        } else {
            label = label ch
        }
        pos++
    }

    if (pos > len || substr(text, pos, 1) != "]" || label_has_unescaped_bracket(label) || normalize_reference_label(label) == "") {
        return 0
    }
    if (length(label) > 999) {
        return 0
    }
    refdef_label = label
    pos++

    if (substr(text, pos, 1) != ":") {
        return 0
    }
    pos++

    pos = skip_spaces_tabs(text, pos)
    if (substr(text, pos, 1) == "\n") {
        pos++
        while (substr(text, pos, 1) == " " || substr(text, pos, 1) == "\t") {
            pos++
        }
    }

    if (pos > len) {
        return 0
    }

    if (substr(text, pos, 1) == "<") {
        pos++
        dest = ""
        while (pos <= len) {
            ch = substr(text, pos, 1)
            if (ch == ">") {
                break
            }
            if (ch == "\n") {
                return 0
            }
            dest = dest ch
            pos++
        }
        if (pos > len || substr(text, pos, 1) != ">") {
            return 0
        }
        pos++
    } else {
        dest = ""
        depth = 0
        escaped = 0
        while (pos <= len) {
            ch = substr(text, pos, 1)
            if (escaped) {
                dest = dest "\\" ch
                escaped = 0
            } else if (ch == "\\") {
                escaped = 1
            } else if (ch == "(") {
                depth++
                dest = dest ch
            } else if (ch == ")") {
                if (depth == 0) {
                    break
                }
                depth--
                dest = dest ch
            } else if (ch == " " || ch == "\t" || ch == "\n") {
                break
            } else {
                dest = dest ch
            }
            pos++
        }
        if (dest == "") {
            return 0
        }
    }

    ch = substr(text, pos, 1)
    if (ch != "" && ch != " " && ch != "\t" && ch != "\n") {
        return 0
    }

    refdef_dest = link_href_escape(decode_character_references_string(unescape_backslash_punctuation(dest)))
    pos = skip_spaces_tabs(text, pos)
    title_start = pos
    title_on_next_line = 0

    if (substr(text, pos, 1) == "\n") {
        scan = pos + 1
        while (substr(text, scan, 1) == " " || substr(text, scan, 1) == "\t") {
            scan++
        }
        if (substr(text, scan, 1) == "\"" || substr(text, scan, 1) == "'" || substr(text, scan, 1) == "(") {
            pos = scan
            title_on_next_line = 1
        } else {
            refdef_consumed = title_start - 1
            return 1
        }
    }

    q = substr(text, pos, 1)
    if (q == "\"" || q == "'" || q == "(") {
        close_ch = q
        if (q == "(") {
            close_ch = ")"
        }
        pos++
        title = ""
        escaped = 0
        while (pos <= len) {
            ch = substr(text, pos, 1)
            if (escaped) {
                title = title "\\" ch
                escaped = 0
            } else if (ch == "\\") {
                escaped = 1
            } else if (ch == close_ch) {
                break
            } else {
                title = title ch
            }
            pos++
        }
        if (pos <= len && substr(text, pos, 1) == close_ch) {
            pos++
            line_rest = substr(text, pos)
            sub(/\n.*$/, "", line_rest)
            if (line_rest ~ /^[ \t]*$/) {
                refdef_title = decode_character_references_string(unescape_backslash_punctuation(title))
                pos = skip_spaces_tabs(text, pos)
                refdef_consumed = pos - 1
                return 1
            }
        }
        if (!title_on_next_line) {
            return 0
        }
    }

    refdef_consumed = title_start - 1
    return 1
}

function skip_spaces_tabs(text, pos) {
    while (substr(text, pos, 1) == " " || substr(text, pos, 1) == "\t") {
        pos++
    }
    return pos
}

function start_list_item(    list_id, item_id, para_id) {
    if (open_node) {
        close_open_block()
    }

    if (pending_list_blank && current_list) {
        node_set_attr(current_list, "loose", 1)
    }

    if (!current_list || current_list_type != matched_list_type || current_list_marker != matched_list_marker) {
        list_id = append_list_block(root_node)
        set_current_list_block(list_id, 0)
        save_list_context()
    }

    item_id = append_list_item(current_list)
    set_current_list_item(item_id)
    pending_list_blank = 0

    if (matched_content == "") {
        open_node = 0
        set_block_state("", "")
        return
    }

    if (match_thematic_break(matched_content)) {
        append_thematic_break_block(item_id)
        set_block_state("", "")
        return
    }

    if (start_list_item_child_block(matched_content)) {
        return
    }

    para_id = append_paragraph_block(item_id, matched_content)
    open_node = para_id
    set_block_state("list", "paragraph")
}

function save_list_context() {
    if (!current_list_depth) {
        return
    }

    list_stack_list[current_list_depth] = current_list
    list_stack_item[current_list_depth] = current_list_item
    list_stack_type[current_list_depth] = current_list_type
    list_stack_marker[current_list_depth] = current_list_marker
    list_stack_marker_indent[current_list_depth] = current_list_marker_indent
    list_stack_content_indent[current_list_depth] = current_list_content_indent
}

function restore_list_context() {
    current_list = list_stack_list[current_list_depth]
    current_list_item = list_stack_item[current_list_depth]
    current_list_type = list_stack_type[current_list_depth]
    current_list_marker = list_stack_marker[current_list_depth]
    current_list_marker_indent = list_stack_marker_indent[current_list_depth]
    current_list_content_indent = list_stack_content_indent[current_list_depth]
}

function set_current_list_block(list_id, in_blockquote) {
    current_list = list_id
    current_list_type = matched_list_type
    current_list_marker = matched_list_marker
    current_list_marker_indent = matched_marker_indent
    current_list_depth = 1
    # The parser stores list and blockquote state separately. This flag marks
    # lists owned by the current blockquote so leaving that quote can clear
    # only those lists, without discarding an outer top-level list.
    current_list_in_blockquote = in_blockquote
}

function set_current_list_item(item_id) {
    current_list_item = item_id
    current_list_content_indent = matched_content_indent
    save_list_context()
}

function push_list_context(list_id, item_id) {
    save_list_context()
    current_list_depth++
    current_list = list_id
    current_list_item = item_id
    current_list_type = matched_list_type
    current_list_marker = matched_list_marker
    current_list_marker_indent = matched_marker_indent
    current_list_content_indent = matched_content_indent
    save_list_context()
}

function close_open_block_if_needed() {
    if (open_node) {
        close_open_block()
    }
}

function finish_list_child_block() {
    pending_list_blank = 0
    return 1
}

function pop_list_context() {
    if (current_list_depth <= 1) {
        return
    }

    current_list_depth--
    restore_list_context()
}

function append_list_block(parent,    list_id) {
    list_id = node_new("list")
    node_set_attr(list_id, "list_type", matched_list_type)
    node_set_attr(list_id, "marker", matched_list_marker)
    if (matched_list_type == "ordered") {
        node_set_attr(list_id, "start", matched_list_start)
    }
    node_append_child(parent, list_id)
    return list_id
}

function append_list_item(list_id,    item_id) {
    item_id = node_new("list_item")
    node_append_child(list_id, item_id)
    return item_id
}

function append_heading_block(parent,    heading_id) {
    heading_id = node_new("heading")
    node_set_attr(heading_id, "level", matched_level)
    node_literal[heading_id] = matched_content
    node_append_child(parent, heading_id)
    open_node = 0
}

function start_fenced_code_block(parent, context,    code_id) {
    code_id = node_new("code_block")
    node_set_attr(code_id, "fenced", 1)
    node_set_attr(code_id, "info", matched_content)
    node_append_child(parent, code_id)
    open_node = code_id
    fence_char = matched_fence_char
    fence_len = matched_fence_len
    fence_indent = matched_fence_indent
    set_block_state(context, "fenced_code")
}

function start_indented_code_block(parent, context, literal, indent,    code_id) {
    code_id = node_new("code_block")
    node_append_child(parent, code_id)
    open_node = code_id
    set_block_state(context, "indented_code")
    if (context == "list") {
        # List code blocks continue relative to the item content column, not
        # relative to the current line after container stripping.
        list_code_indent = indent
    }
    node_append_literal(open_node, literal)
}

function append_indented_code_block(parent, literal,    code_id) {
    code_id = node_new("code_block")
    node_append_child(parent, code_id)
    node_append_literal(code_id, literal)
    open_node = 0
}

function append_thematic_break_block(parent,    hr_id) {
    hr_id = node_new("thematic_break")
    node_append_child(parent, hr_id)
    open_node = 0
}

function start_html_block(parent, context, content, end_marker,    html_id) {
    html_id = node_new("html_block")
    node_append_child(parent, html_id)
    open_node = html_id
    html_block_end = end_marker
    set_block_state(context, "html_block")
    node_append_literal(open_node, content)
    return html_id
}

function start_blockquote_child(parent, content,    quote_id) {
    quote_id = node_new("block_quote")
    node_append_child(parent, quote_id)
    current_block_quote = quote_id
    current_block_quote_depth = 1
    append_blockquote_content(content)
}

function append_paragraph_block(parent, literal,    para_id) {
    para_id = node_new("paragraph")
    node_append_child(parent, para_id)
    node_literal[para_id] = literal
    node_has_literal[para_id] = 1
    return para_id
}

function start_nested_list_child(parent_item, parent_indent,    nested_list, item_id) {
    matched_marker_indent += parent_indent
    matched_content_indent += parent_indent
    nested_list = append_list_block(parent_item)
    item_id = append_list_item(nested_list)
    push_list_context(nested_list, item_id)
}

function start_nested_list_child_with_content(parent_item, parent_indent, content) {
    start_nested_list_child(parent_item, parent_indent)
    if (content != "") {
        if (start_list_item_child_block(content)) {
            return 1
        }
        append_paragraph_block(current_list_item, content)
    }
    open_node = 0
    set_block_state("", "")
    return 1
}

function start_list_item_child_block(content,    parent_indent) {
    if (match_atx_heading(content)) {
        append_heading_block(current_list_item)
        set_block_state("", "")
        return 1
    }

    if (match_opening_fence(content)) {
        start_fenced_code_block(current_list_item, "list")
        return 1
    }

    if (leading_spaces(content) >= 4) {
        start_indented_code_block(current_list_item, "list", strip_indent(content, 4), 4)
        return 1
    }

    if (match_blockquote_marker(content)) {
        start_blockquote_child(current_list_item, matched_content)
        return 1
    }

    if (match_thematic_break(content)) {
        append_thematic_break_block(current_list_item)
        set_block_state("", "")
        return 1
    }

    if (match_list_marker(content)) {
        parent_indent = current_list_content_indent
        return start_nested_list_child_with_content(current_list_item, parent_indent, matched_content)
    }

    return 0
}

function start_list_continuation_paragraph(line,    para_id) {
    if (pending_list_blank && current_list) {
        node_set_attr(current_list, "loose", 1)
    }
    para_id = append_paragraph_block(current_list_item, strip_list_continuation(line))
    open_node = para_id
    set_block_state("list", "paragraph")
    pending_list_blank = 0
}

function start_list_child_block(line,    content, parent_indent) {
    content = strip_list_continuation(line)

    if (pending_list_blank && leading_spaces(line) >= current_list_content_indent + 4) {
        close_open_block_if_needed()
        node_set_attr(current_list, "loose", 1)
        start_indented_code_block(current_list_item, "list", strip_indent(line, current_list_content_indent + 4), current_list_content_indent + 4)
        return finish_list_child_block()
    }

    if (match_opening_fence(content)) {
        close_open_block_if_needed()
        start_fenced_code_block(current_list_item, "list")
        return finish_list_child_block()
    }

    if (match_blockquote_marker(content)) {
        close_open_block_if_needed()
        start_blockquote_child(current_list_item, matched_content)
        return finish_list_child_block()
    }

    if (!node_first_child[current_list_item] && leading_spaces(content) >= 4) {
        start_indented_code_block(current_list_item, "list", strip_indent(content, 4), current_list_content_indent + 4)
        return finish_list_child_block()
    }

    if (match_list_marker(content)) {
        close_open_block_if_needed()
        parent_indent = current_list_content_indent
        if (pending_list_blank && current_list) {
            node_set_attr(current_list, "loose", 1)
        }
        start_nested_list_child_with_content(current_list_item, parent_indent, matched_content)
        return finish_list_child_block()
    }

    return 0
}

function start_blockquote(    quote_id) {
    quote_id = node_new("block_quote")
    node_append_child(root_node, quote_id)
    current_block_quote = quote_id
    current_block_quote_depth = 1

    append_blockquote_content(matched_content)
}

function start_nested_blockquote(content,    quote_id) {
    quote_id = node_new("block_quote")
    node_append_child(current_block_quote, quote_id)
    current_block_quote = quote_id
    current_block_quote_depth++
    append_blockquote_content(content)
}

function start_blockquote_list(content,    list_id, item_id, quote_id, para_id) {
    list_id = append_list_block(current_block_quote)
    item_id = append_list_item(list_id)
    set_current_list_block(list_id, 1)
    set_current_list_item(item_id)

    if (content != "") {
        if (match_blockquote_marker(content)) {
            quote_id = node_new("block_quote")
            node_append_child(item_id, quote_id)
            para_id = append_paragraph_block(quote_id, matched_content)
            current_block_quote = quote_id
            open_node = para_id
            set_block_state("blockquote", "paragraph")
            return
        }
        append_paragraph_block(item_id, content)
    }
    open_node = 0
    set_block_state("blockquote", "")
}

function start_blockquote_paragraph(content,    para_id) {
    para_id = append_paragraph_block(current_block_quote, content)
    open_node = para_id
    set_block_state("blockquote", "paragraph")
}

function line_interrupts_paragraph(line) {
    if (match_atx_heading(line) || match_thematic_break(line) || match_opening_fence(line) || match_blockquote_marker(line)) {
        return 1
    }
    if (match_html_block_start(line) && matched_html_block_can_interrupt) {
        return 1
    }
    return 0
}

function append_blockquote_content(content) {
    if (current_list && leading_spaces(content) >= current_list_content_indent) {
        if (start_list_child_block(content)) {
            set_block_state("blockquote", "")
            return
        }
        start_list_continuation_paragraph(content)
        return
    }

    if (match_blockquote_marker(content)) {
        start_nested_blockquote(matched_content)
        return
    }

    if (is_blank(content)) {
        if (current_list) {
            # A blank line inside a list may make it loose once content resumes.
            pending_list_blank = 1
        }
        set_block_state("blockquote", "")
        open_node = 0
        return
    }

    if (match_atx_heading(content)) {
        append_heading_block(current_block_quote)
        set_block_state("blockquote", "")
        return
    }

    if (match_opening_fence(content)) {
        start_fenced_code_block(current_block_quote, "blockquote")
        return
    }

    if (leading_spaces(content) >= 4) {
        append_indented_code_block(current_block_quote, strip_indent(content, 4))
        set_block_state("blockquote", "")
        return
    }

    if (match_list_marker(content)) {
        start_blockquote_list(matched_content)
        return
    }

    if (match_html_block_start(content)) {
        start_html_block(current_block_quote, "blockquote", content, matched_html_block_end)
        return
    }

    start_blockquote_paragraph(content)
}

function match_atx_heading(line,    text, indent, hashes, rest, closing) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = line
    text = substr(text, indent + 1)

    if (text !~ /^#{1,6}([ \t]|$)/) {
        return 0
    }

    hashes = text
    sub(/[^#].*$/, "", hashes)
    matched_level = length(hashes)
    rest = substr(text, matched_level + 1)
    sub(/^[ \t]+/, "", rest)
    sub(/[ \t]+$/, "", rest)

    if (rest ~ /^#+$/) {
        rest = ""
    } else if (rest ~ /[ \t]#+$/) {
        closing = rest
        sub(/^.*[ \t]/, "", closing)
        if (closing ~ /^#+$/) {
            sub(/[ \t]#+$/, "", rest)
            sub(/[ \t]+$/, "", rest)
        }
    }

    matched_content = rest
    return 1
}

function match_setext_heading(line,    text, indent) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = line
    text = substr(text, indent + 1)
    sub(/[ \t]+$/, "", text)

    if (text ~ /^=+$/) {
        matched_level = 1
        return 1
    }
    if (text ~ /^-+$/) {
        matched_level = 2
        return 1
    }
    return 0
}

function match_thematic_break(line,    text, indent, i, ch, marker, count) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = line
    text = substr(text, indent + 1)
    sub(/[ \t]+$/, "", text)

    marker = ""
    count = 0
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == " " || ch == "\t") {
            continue
        }
        if (ch != "*" && ch != "-" && ch != "_") {
            return 0
        }
        if (marker == "") {
            marker = ch
        } else if (ch != marker) {
            return 0
        }
        count++
    }

    return count >= 3
}

function match_opening_fence(line,    text, indent, i, ch, marker, count, info) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = line
    text = substr(text, indent + 1)

    marker = substr(text, 1, 1)
    if (marker != "`" && marker != "~") {
        return 0
    }

    count = 0
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == marker) {
            count++
        } else {
            break
        }
    }

    if (count < 3) {
        return 0
    }

    info = trim(substr(text, count + 1))
    if (marker == "`" && index(info, "`")) {
        return 0
    }

    matched_fence_char = marker
    matched_fence_len = count
    matched_fence_indent = indent
    matched_content = info
    return 1
}

function match_list_marker(line,    text, indent, marker, rest, digits, i, ch, after_marker, padding, marker_cols) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    matched_marker_indent = indent

    text = substr(line, indent + 1)
    marker = substr(text, 1, 1)
    if ((marker == "-" || marker == "+" || marker == "*") && (length(text) == 1 || substr(text, 2, 1) ~ /^[ \t]$/)) {
        after_marker = substr(text, 2)
        padding = marker_padding_columns(after_marker, 1)
        if (substr(after_marker, 1, 1) == "\t") {
            padding = 1
        }
        if (after_marker ~ /^[ \t]*$/) {
            padding = 1
        }
        if (padding == 0 || padding > 4) {
            padding = 1
        }
        matched_list_type = "bullet"
        matched_list_marker = marker
        matched_list_start = 0
        matched_content_indent = indent + 1 + padding
        matched_content = strip_indent_from(after_marker, padding, indent + 1)
        if (after_marker ~ /^[ \t]*$/) {
            matched_content = ""
        }
        return 1
    }

    digits = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch ~ /^[0-9]$/) {
            digits = digits ch
        } else {
            break
        }
    }

    if (digits != "" && length(digits) <= 9) {
        marker = substr(text, length(digits) + 1, 1)
        rest = substr(text, length(digits) + 2, 1)
        if ((marker == "." || marker == ")") && (rest == "" || rest ~ /^[ \t]$/)) {
            marker_cols = length(digits) + 1
            after_marker = substr(text, length(digits) + 2)
            padding = marker_padding_columns(after_marker, marker_cols)
            if (substr(after_marker, 1, 1) == "\t") {
                padding = 1
            }
            if (after_marker ~ /^[ \t]*$/) {
                padding = 1
            }
            if (padding == 0 || padding > 4) {
                padding = 1
            }
            matched_list_type = "ordered"
            matched_list_marker = marker
            matched_list_start = digits + 0
            matched_content_indent = indent + marker_cols + padding
            matched_content = strip_indent_from(after_marker, padding, indent + marker_cols)
            if (after_marker ~ /^[ \t]*$/) {
                matched_content = ""
            }
            return 1
        }
    }

    return 0
}

function marker_padding_columns(text, base_col,    i, col, ch) {
    col = base_col
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == " ") {
            col++
        } else if (ch == "\t") {
            col += 4 - (col % 4)
        } else {
            return col - base_col
        }
    }
    return col - base_col
}

function list_can_interrupt_paragraph() {
    if (matched_content == "") {
        return 0
    }
    return matched_list_type == "bullet" || matched_list_start == 1
}

function match_blockquote_marker(line,    text, indent, after_col, tab_col, spaces) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = substr(line, indent + 1)
    if (substr(text, 1, 1) != ">") {
        return 0
    }
    text = substr(text, 2)
    after_col = indent + 1
    if (substr(text, 1, 1) == " ") {
        text = substr(text, 2)
        after_col++
    } else if (substr(text, 1, 1) == "\t") {
        tab_col = after_col + 4 - (after_col % 4)
        spaces = tab_col - after_col - 1
        text = repeat_spaces(spaces) expand_tabs_from(substr(text, 2), tab_col)
        matched_content = text
        return 1
    }
    matched_content = expand_tabs_from(text, after_col)
    return 1
}

function strip_blockquote_markers(line, depth,    i, content) {
    if (depth < 1) {
        return 0
    }
    content = line
    for (i = 1; i <= depth; i++) {
        if (!match_blockquote_marker(content)) {
            return 0
        }
        content = matched_content
    }
    matched_content = content
    return 1
}

function strip_blockquote_markers_upto(line, depth,    i, content, stripped) {
    if (depth < 1) {
        return 0
    }
    content = line
    stripped = 0
    for (i = 1; i <= depth; i++) {
        if (!match_blockquote_marker(content)) {
            break
        }
        content = matched_content
        stripped++
    }
    if (!stripped) {
        return 0
    }
    matched_content = content
    return 1
}

function strip_list_continuation(line,    indent) {
    indent = leading_spaces(line)
    if (indent >= current_list_content_indent) {
        return strip_indent(line, current_list_content_indent)
    }
    return line
}

function is_closing_fence(line,    text, indent, i, ch, count, rest) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = line
    text = substr(text, indent + 1)

    count = 0
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == fence_char) {
            count++
        } else {
            break
        }
    }

    if (count < fence_len) {
        return 0
    }

    rest = substr(text, count + 1)
    return rest ~ /^[ \t]*$/
}

function match_html_block_start(line,    text, indent, lower) {
    indent = leading_spaces(line)
    if (indent > 3) {
        return 0
    }
    text = substr(line, indent + 1)
    lower = tolower(text)
    matched_html_block_end = "blank"
    matched_html_block_can_interrupt = 1

    if (text ~ /^<!--/) {
        matched_html_block_end = "-->"
        return 1
    }
    if (text ~ /^<\?/) {
        matched_html_block_end = "?>"
        return 1
    }
    if (text ~ /^<![A-Z]/) {
        matched_html_block_end = ">"
        return 1
    }
    if (text ~ /^<!\[CDATA\[/) {
        matched_html_block_end = "]]>"
        return 1
    }
    if (lower ~ /^<(script|pre|style|textarea)([ \t>]|$)/) {
        if (lower ~ /^<script([ \t>]|$)/) {
            matched_html_block_end = "</script>"
        } else if (lower ~ /^<pre([ \t>]|$)/) {
            matched_html_block_end = "</pre>"
        } else if (lower ~ /^<style([ \t>]|$)/) {
            matched_html_block_end = "</style>"
        } else {
            matched_html_block_end = "</textarea>"
        }
        return 1
    }
    if (lower ~ /^<\/?(address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)([ \t>\/]|$)/) {
        return 1
    }
    matched_html_block_can_interrupt = 0
    if (text ~ /^<[^>]+>[ \t]*$/) {
        sub(/[ \t]*$/, "", text)
        return is_raw_html_inline(substr(text, 2, length(text) - 2))
    }
    return 0
}
