function nodes_init() {
    node_count = 0
}

function node_new(type,    id) {
    id = ++node_count
    node_type[id] = type
    node_literal[id] = ""
    node_has_literal[id] = 0
    node_first_child[id] = 0
    node_last_child[id] = 0
    node_next[id] = 0
    return id
}

function node_append_child(parent, child,    last) {
    node_parent[child] = parent
    last = node_last_child[parent]

    if (last) {
        node_next[last] = child
    } else {
        node_first_child[parent] = child
    }

    node_last_child[parent] = child
}

function node_append_literal(id, text) {
    if (!node_has_literal[id]) {
        node_literal[id] = text
        node_has_literal[id] = 1
    } else {
        node_literal[id] = node_literal[id] "\n" text
    }
}

function node_set_attr(id, key, value) {
    node_attr[id, key] = value
}

function node_attr_value(id, key) {
    return node_attr[id, key]
}
