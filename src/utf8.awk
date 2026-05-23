function is_ascii_character(ch,    i) {
    if (!ascii_character_cache_ready) {
        for (i = 1; i < 128; i++) {
            ascii_character_cache[sprintf("%c", i)] = 1
        }
        ascii_character_cache_ready = 1
    }
    return ch in ascii_character_cache
}

function utf8_percent_encode(ch,    codepoint, b1, b2, b3, b4) {
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
