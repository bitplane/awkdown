BEGIN {
    blocks_init()
}

{
    blocks_process_line($0)
}

END {
    blocks_finish()
    render_document()
}
