"""
    url_encode(str)

Simple URL encoding for query parameters.
Replaces spaces and special characters with percent-encoded equivalents.
"""
function url_encode(str::String)::String
    # Replace common characters that need encoding in URLs
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
    # Only decode if string contains entities (performance optimization)
    if !occursin('&', str)
        return str
    end

    # Common HTML entities in OSM data
    str = replace(str, "&amp;" => "&")
    str = replace(str, "&lt;" => "<")
    str = replace(str, "&gt;" => ">")
    str = replace(str, "&quot;" => "\"")
    str = replace(str, "&#39;" => "'")
    str = replace(str, "&apos;" => "'")
    return str
end

"""
    readosm(filename; node_callback, way_callback, relation_callback)

Read OpenStreetMap data from an XML file.

# Arguments
- `filename::String`: Path to the OSM XML file to read

# Keyword Arguments
- `node_callback::Union{Function,Nothing}=nothing`: Optional callback function for filtering nodes
- `way_callback::Union{Function,Nothing}=nothing`: Optional callback function for filtering ways
- `relation_callback::Union{Function,Nothing}=nothing`: Optional callback function for filtering relations

# Callback Functions
Callback functions should accept one argument of the respective type (`Node`, `Way`, or `Relation`) and return either:
- An object of the same type (element will be included in the result)
- `nothing` (element will be excluded from the result)

# Returns
- `OpenStreetMap`: Complete OSM dataset with nodes, ways, relations, and metadata

# Examples
```julia
# Read all data
osmdata = readosm("map.osm")

# Filter to only include restaurants
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end
osmdata = readosm("map.osm", node_callback=keep_restaurants)
```

# See Also
- [`readpbf`](@ref): Read OSM PBF files
- [`queryoverpass`](@ref): Query data from Overpass API
"""
function readosm(
        filename::String;
        node_callback::Union{Function, Nothing} = nothing,
        way_callback::Union{Function, Nothing} = nothing,
        relation_callback::Union{Function, Nothing} = nothing,
    )::OpenStreetMap
    # Validate file exists and is readable
    isfile(filename) || throw(ArgumentError("File '$filename' does not exist"))

    # Read XML document using registered XML.jl
    doc = XML.read(filename, XML.Node)
    return parse_osm(
        doc;
        node_callback = node_callback,
        way_callback = way_callback,
        relation_callback = relation_callback,
    )
end

"""
    queryoverpass(bbox; kwargs...)

Query OpenStreetMap data from Overpass API using a bounding box.

# Arguments
- `bbox::BBox`: Geographic bounding box to query

# Keyword Arguments
- `timeout::Int64=25`: Query timeout in seconds

# Returns
- `OpenStreetMap`: OSM data within the specified bounding box

# Examples
```julia
bbox = BBox(54.0, 9.0, 55.0, 10.0)
osmdata = queryoverpass(bbox)
```
"""
function queryoverpass(bbox::BBox; kwargs...)::OpenStreetMap
    osmdata = queryoverpass(
        "$(bbox.bottom_lat),$(bbox.left_lon),$(bbox.top_lat),$(bbox.right_lon)"; kwargs...
    )
    return osmdata
end

"""
    queryoverpass(lonlat, radius; kwargs...)

Query OpenStreetMap data from Overpass API using a center point and radius.

# Arguments
- `lonlat::LatLon`: Center point for the query
- `radius::Real`: Radius in meters around the center point

# Keyword Arguments
- `timeout::Int64=25`: Query timeout in seconds

# Returns
- `OpenStreetMap`: OSM data within the specified radius

# Examples
```julia
center = LatLon(54.2619665, 9.9854149)
osmdata = queryoverpass(center, 1000)  # 1km radius
```
"""
function queryoverpass(lonlat::LatLon, radius::Real; kwargs...)
    osmdata = queryoverpass("around:$radius,$(lonlat.lat),$(lonlat.lon)"; kwargs...)
    return osmdata
end

"""
    queryoverpass(bounds; timeout)

Query OpenStreetMap data from Overpass API using a bounds string.

# Arguments
- `bounds::String`: Bounds string in Overpass API format (e.g., "54.0,9.0,55.0,10.0" or "around:1000,54.0,9.0")

# Keyword Arguments
- `timeout::Int64=25`: Query timeout in seconds

# Returns
- `OpenStreetMap`: OSM data matching the query

# Examples
```julia
# Bounding box query
osmdata = queryoverpass("54.0,9.0,55.0,10.0")

# Radius query
osmdata = queryoverpass("around:1000,54.2619665,9.9854149")
```

# See Also
- [`readpbf`](@ref): Read OSM PBF files
- [`readosm`](@ref): Read OSM XML files
"""
function queryoverpass(bounds::String; timeout::Int64 = 25)::OpenStreetMap
    query = """
    	[out:xml][timeout:$timeout];
    	(
    		node($bounds);
    		way($bounds);
    		relation($bounds);
    	);
    	out body;
    	>;
    	out skel qt;
    """

    # Use Downloads.download for HTTP requests
    url = "https://overpass-api.de/api/interpreter?data=$(url_encode(query))"
    response_body = download(url)
    node = XML.read(IOBuffer(response_body), XML.Node)
    return parse_osm(node)
end

"""
    parse_osm(xmldoc; node_callback, way_callback, relation_callback)

Parse XML document and return OpenStreetMap data structure.
Optimized for performance with early returns and efficient parsing.

# Arguments
- `xmldoc::XML.Node`: XML document node to parse

# Keyword Arguments
- `node_callback::Union{Function,Nothing}=nothing`: Optional callback function for filtering nodes
- `way_callback::Union{Function,Nothing}=nothing`: Optional callback function for filtering ways
- `relation_callback::Union{Function,Nothing}=nothing`: Optional callback function for filtering relations

# Returns
- `OpenStreetMap`: Parsed OSM data structure

# Internal function used by `readosm`.
"""
function parse_osm(
        xmldoc::XML.Node;
        node_callback::Union{Function, Nothing} = nothing,
        way_callback::Union{Function, Nothing} = nothing,
        relation_callback::Union{Function, Nothing} = nothing,
    )::OpenStreetMap
    osmdata = OpenStreetMap()

    # Find the OSM root element efficiently
    osmroot = find_osm_root(xmldoc)
    osmroot === nothing && return osmdata

    # Pre-allocate containers for better performance
    children = XML.children(osmroot)
    n_children = length(children)

    # Process elements in batches for better cache locality
    for xmlnode in children
        elname = XML.tag(xmlnode)
        if elname == "bounds"
            osmdata.meta["bbox"] = parse_bounds(xmlnode)
        elseif elname == "node"
            try
                id, node = parse_node(xmlnode)
                if node_callback !== nothing
                    filtered_node = node_callback(node)
                    if filtered_node !== nothing
                        osmdata.nodes[id] = filtered_node
                    end
                else
                    osmdata.nodes[id] = node
                end
            catch e
                @warn "Error processing node: $e"
                continue
            end
        elseif elname == "way"
            try
                id, way = parse_way(xmlnode)
                if way_callback !== nothing
                    filtered_way = way_callback(way)
                    if filtered_way !== nothing
                        osmdata.ways[id] = filtered_way
                    end
                else
                    osmdata.ways[id] = way
                end
            catch e
                @warn "Error processing way: $e"
                continue
            end
        elseif elname == "relation"
            try
                id, relation = parse_relation(xmlnode)
                if relation_callback !== nothing
                    filtered_relation = relation_callback(relation)
                    if filtered_relation !== nothing
                        osmdata.relations[id] = filtered_relation
                    end
                else
                    osmdata.relations[id] = relation
                end
            catch e
                @warn "Error processing relation: $e"
                continue
            end
        else
            merge!(osmdata.meta, parse_unknown_element(xmlnode))
        end
    end

    return osmdata
end

"""
    find_osm_root(xmldoc)

Efficiently find the OSM root element in the XML document.
"""
function find_osm_root(xmldoc::XML.Node)::Union{XML.Node, Nothing}
    for xmlnode in XML.children(xmldoc)
        XML.tag(xmlnode) == "osm" && return xmlnode
    end
    return nothing
end

"""
    parse_bounds(xmlnode)

Parse bounds element into BBox structure.
Optimized for performance with direct attribute access.
"""
function parse_bounds(xmlnode::XML.Node)::BBox
    attrs = XML.attributes(xmlnode)
    return BBox(
        parse(Float64, attrs["minlat"]),
        parse(Float64, attrs["minlon"]),
        parse(Float64, attrs["maxlat"]),
        parse(Float64, attrs["maxlon"]),
    )
end

"""
    parse_node(xmlnode)

Parse node element into (id, Node) tuple.
Optimized for performance with efficient tag parsing.
"""
function parse_node(xmlnode::XML.Node)::Tuple{Int64, Node}
    attrs = XML.attributes(xmlnode)
    id = parse(Int64, attrs["id"])
    latlon = LatLon(parse(Float64, attrs["lat"]), parse(Float64, attrs["lon"]))

    # Parse tags efficiently
    tags = parse_tags(xmlnode)
    return id, Node(latlon, tags)
end

"""
    parse_way(xmlnode)

Parse way element into (id, Way) tuple.
Optimized for performance with efficient node reference and tag parsing.
"""
function parse_way(xmlnode::XML.Node)::Tuple{Int64, Way}
    attrs = XML.attributes(xmlnode)
    id = parse(Int64, attrs["id"])

    # Parse node references and tags efficiently
    refs, tags = parse_way_children(xmlnode)
    return id, Way(refs, tags)
end

"""
    parse_relation(xmlnode)

Parse relation element into (id, Relation) tuple.
Optimized for performance with efficient member and tag parsing.
"""
function parse_relation(xmlnode::XML.Node)::Tuple{Int64, Relation}
    attrs = XML.attributes(xmlnode)
    id = parse(Int64, attrs["id"])

    # Parse members and tags efficiently
    refs, types, roles, tags = parse_relation_children(xmlnode)
    return id, Relation(refs, types, roles, tags)
end

"""
    parse_unknown_element(xmlnode)

Parse unknown XML elements into a dictionary.
Optimized for performance with efficient attribute and child processing.
"""
function parse_unknown_element(xmlnode::XML.Node)::Dict{String, Any}
    out = Dict{String, Any}()

    # Process attributes efficiently
    for (k, v) in XML.attributes(xmlnode)
        out[String(k)] = String(v)
    end

    # Process children recursively
    children = XML.children(xmlnode)
    if !isempty(children)
        for subxmlnode in children
            elname = XML.tag(subxmlnode)
            out[elname] = parse_unknown_element(subxmlnode)
        end
    end

    return out
end

# Helper functions for efficient parsing

"""
    parse_tags(xmlnode)

Parse all tag elements from an XML node efficiently.
Returns nothing if no tags, or Dict{String,String} with tag data.
"""
function parse_tags(xmlnode::XML.Node)::Union{Dict{String, String}, Nothing}
    children = XML.children(xmlnode)
    isempty(children) && return nothing

    tags = nothing
    for subxmlnode in children
        XML.tag(subxmlnode) == "tag" || continue

        if tags === nothing
            tags = Dict{String, String}()
        end

        tag_attrs = XML.attributes(subxmlnode)
        tags[tag_attrs["k"]] = decode_html_entities(tag_attrs["v"])
    end

    return tags
end

"""
    parse_way_children(xmlnode)

Parse way children (node references and tags) efficiently.
Returns (refs::Vector{Int64}, tags::Union{Dict{String,String}, Nothing}).
"""
function parse_way_children(
        xmlnode::XML.Node
    )::Tuple{Vector{Int64}, Union{Dict{String, String}, Nothing}}
    children = XML.children(xmlnode)
    isempty(children) && return Int64[], nothing

    refs = Int64[]
    tags = nothing

    for subxmlnode in children
        elname = XML.tag(subxmlnode)
        if elname == "nd"
            nd_attrs = XML.attributes(subxmlnode)
            push!(refs, parse(Int64, nd_attrs["ref"]))
        elseif elname == "tag"
            if tags === nothing
                tags = Dict{String, String}()
            end
            tag_attrs = XML.attributes(subxmlnode)
            tags[tag_attrs["k"]] = decode_html_entities(tag_attrs["v"])
        end
    end

    return refs, tags
end

"""
    parse_relation_children(xmlnode)

Parse relation children (members and tags) efficiently.
Returns (refs::Vector{Int64}, types::Vector{String}, roles::Vector{String}, tags::Union{Dict{String,String}, Nothing}).
"""
function parse_relation_children(
        xmlnode::XML.Node
    )::Tuple{Vector{Int64}, Vector{String}, Vector{String}, Union{Dict{String, String}, Nothing}}
    children = XML.children(xmlnode)
    isempty(children) && return Int64[], String[], String[], nothing

    refs = Int64[]
    types = String[]
    roles = String[]
    tags = nothing

    for subxmlnode in children
        elname = XML.tag(subxmlnode)
        if elname == "member"
            member_attrs = XML.attributes(subxmlnode)
            push!(refs, parse(Int64, member_attrs["ref"]))
            push!(types, member_attrs["type"])
            push!(roles, member_attrs["role"])
        elseif elname == "tag"
            if tags === nothing
                tags = Dict{String, String}()
            end
            tag_attrs = XML.attributes(subxmlnode)
            tags[tag_attrs["k"]] = decode_html_entities(tag_attrs["v"])
        end
    end

    return refs, types, roles, tags
end
