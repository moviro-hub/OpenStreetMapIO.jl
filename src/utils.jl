"""
    url_encode(str)

Simple URL encoding for query parameters.
Replaces spaces and selected special characters with percent-encoded equivalents.
"""
function url_encode(str::String)::String
    str = replace(str, " " => "%20")
    str = replace(str, "\n" => "%0A")
    str = replace(str, "\r" => "%0D")
    str = replace(str, "\t" => "%09")
    str = replace(str, "[" => "%5B")
    str = replace(str, "]" => "%5D")
    str = replace(str, "(" => "%28")
    str = replace(str, ")" => "%29")
    str = replace(str, ";" => "%3B")
    str = replace(str, "," => "%2C")
    str = replace(str, "=" => "%3D")
    str = replace(str, "&" => "%26")
    str = replace(str, ">" => "%3E")
    str = replace(str, "<" => "%3C")
    str = replace(str, ":" => "%3A")
    return str
end

"""
    decode_html_entities(str)

Decode HTML entities in a string to their actual characters.
Optimized for common OSM entities.
"""
function decode_html_entities(str::String)::String
    if !occursin('&', str)
        return str
    end
    str = replace(str, "&amp;" => "&")
    str = replace(str, "&lt;" => "<")
    str = replace(str, "&gt;" => ">")
    str = replace(str, "&quot;" => "\"")
    str = replace(str, "&#39;" => "'")
    str = replace(str, "&apos;" => "'")
    return str
end
