"""
    readpbf(filename; node_callback, way_callback, relation_callback)

Read OpenStreetMap data from a PBF (Protocol Buffer Format) file.

# Arguments
- `filename::String`: Path to the PBF file to read

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
osmdata = readpbf("map.pbf")

# Filter to only include restaurants
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end
osmdata = readpbf("map.pbf", node_callback=keep_restaurants)

# Filter multiple element types
osmdata = readpbf("map.pbf",
    node_callback=keep_restaurants,
    way_callback=way -> way.tags !== nothing && haskey(way.tags, "highway") ? way : nothing
)
```

# See Also
- [`readosm`](@ref): Read OSM XML files
- [`queryoverpass`](@ref): Query data from Overpass API
"""
function readpbf(
        filename::String;
        node_callback::Union{Function, Nothing} = nothing,
        way_callback::Union{Function, Nothing} = nothing,
        relation_callback::Union{Function, Nothing} = nothing,
    )::OpenStreetMap
    # Validate file exists and is readable
    isfile(filename) || throw(ArgumentError("File '$filename' does not exist"))

    osmdata = OpenStreetMap()

    try
        open(filename, "r") do f
            # Read and process header block
            blobheader, blob = read_next_blob(f)
            validate_blob_type(blobheader, "OSMHeader")

            header_block = decode_blob(blob, OSMPBF.HeaderBlock)
            process_header_block!(osmdata, header_block)

            # Process data blocks
            while !eof(f)
                blobheader, blob = read_next_blob(f)
                validate_blob_type(blobheader, "OSMData")

                primitive_block = decode_blob(blob, OSMPBF.PrimitiveBlock)
                process_primitive_block!(
                    osmdata, primitive_block, node_callback, way_callback, relation_callback
                )
            end
        end
    catch e
        if isa(e, SystemError)
            throw(ArgumentError("Cannot read file '$filename': $(e.msg)"))
        else
            rethrow(e)
        end
    end

    return osmdata
end

"""
    read_next_blob(f)

Read the next blob header and blob data from a PBF file stream.
Optimized for performance with efficient memory allocation.

# Arguments
- `f`: File stream opened for reading

# Returns
- `Tuple{OSMPBF.BlobHeader, OSMPBF.Blob}`: Blob header and blob data

# Throws
- `EOFError`: If file ends unexpectedly
- `ArgumentError`: If blob data is corrupted

# Internal function used by `readpbf`.
"""
function read_next_blob(f)::Tuple{OSMPBF.BlobHeader, OSMPBF.Blob}
    # Read blob header size
    header_size_bytes = read(f, UInt32)
    eof(f) && throw(EOFError("Unexpected end of file while reading blob header size"))

    header_size = ntoh(header_size_bytes)
    header_size > 64 * 1024 &&
        throw(ArgumentError("Blob header size too large: $header_size bytes"))

    # Read blob header
    header_data = read(f, header_size)
    eof(f) && throw(EOFError("Unexpected end of file while reading blob header"))

    blobheader = decode(ProtoDecoder(PipeBuffer(header_data)), OSMPBF.BlobHeader)

    # Validate blob header
    blobheader.datasize > 32 * 1024 * 1024 &&
        throw(ArgumentError("Blob data size too large: $(blobheader.datasize) bytes"))

    # Read blob data
    blob_data = read(f, blobheader.datasize)
    length(blob_data) != blobheader.datasize && throw(EOFError("Incomplete blob data read"))

    blob = decode(ProtoDecoder(PipeBuffer(blob_data)), OSMPBF.Blob)

    return blobheader, blob
end

"""
    validate_blob_type(blobheader, expected_type)

Validate that the blob header has the expected type.

# Arguments
- `blobheader::OSMPBF.BlobHeader`: Blob header to validate
- `expected_type::String`: Expected blob type ("OSMHeader" or "OSMData")

# Throws
- `ArgumentError`: If blob type doesn't match expected type

# Internal function used by `readpbf`.
"""
function validate_blob_type(blobheader::OSMPBF.BlobHeader, expected_type::String)
    actual_type = blobheader.var"#type"
    return if actual_type != expected_type
        throw(ArgumentError("Expected blob type '$expected_type', got '$actual_type'"))
    end
end

"""
    decode_blob(blob, block_type)

Decode a blob into either a HeaderBlock or PrimitiveBlock.
Optimized for performance with efficient decompression handling.

# Arguments
- `blob::OSMPBF.Blob`: Blob data to decode
- `block_type`: Type to decode into (`OSMPBF.HeaderBlock` or `OSMPBF.PrimitiveBlock`)

# Returns
- Decoded block of the specified type

# Throws
- `ArgumentError`: If blob contains unsupported or corrupted data format

# Internal function used by `readpbf`.
"""
function decode_blob(
        blob::OSMPBF.Blob,
        block_type::Union{Type{OSMPBF.HeaderBlock}, Type{OSMPBF.PrimitiveBlock}},
    )
    # Validate blob has a data payload (ProtoBuf oneof)
    if isnothing(blob.data)
        throw(ArgumentError("Blob contains no data"))
    end

    return try
        if blob.data.name === :raw
            # Raw (uncompressed) data
            return decode(ProtoDecoder(PipeBuffer(blob.data[])), block_type)
        elseif blob.data.name === :zlib_data
            # Zlib compressed data
            return decode(
                ProtoDecoder(ZlibDecompressorStream(IOBuffer(blob.data[]))), block_type
            )
        else
            throw(ArgumentError("Unsupported blob compression: $(blob.data.name)"))
        end
    catch e
        if isa(e, ProtoBuf.ProtoError)
            throw(ArgumentError("Failed to decode blob: $(e.msg)"))
        else
            rethrow(e)
        end
    end
end

"""
    process_header_block!(osmdata, header)

Process header block and extract metadata into the OpenStreetMap object.
Robustly handles missing or invalid header fields.

# Arguments
- `osmdata::OpenStreetMap`: OSM data object to update
- `header::OSMPBF.HeaderBlock`: Header block from PBF file

# Internal function used by `readpbf`.
"""
function process_header_block!(osmdata::OpenStreetMap, header::OSMPBF.HeaderBlock)
    # Process bounding box with validation
    if hasproperty(header, :bbox) && header.bbox !== nothing
        bbox = header.bbox
        try
            osmdata.meta["bbox"] = BBox(
                Float32(round(1.0e-9 * bbox.bottom; digits = 7)),
                Float32(round(1.0e-9 * bbox.left; digits = 7)),
                Float32(round(1.0e-9 * bbox.top; digits = 7)),
                Float32(round(1.0e-9 * bbox.right; digits = 7)),
            )
        catch e
            @warn "Invalid bounding box in header: $e"
        end
    end

    # Process replication metadata
    if hasproperty(header, :osmosis_replication_timestamp) &&
            header.osmosis_replication_timestamp !== nothing
        try
            osmdata.meta["writenat"] = unix2datetime(header.osmosis_replication_timestamp)
        catch e
            @warn "Invalid timestamp in header: $e"
        end
    end

    if hasproperty(header, :osmosis_replication_sequence_number) &&
            header.osmosis_replication_sequence_number !== nothing
        osmdata.meta["sequencenumber"] = header.osmosis_replication_sequence_number
    end

    if hasproperty(header, :osmosis_replication_base_url) &&
            header.osmosis_replication_base_url !== nothing
        osmdata.meta["baseurl"] = header.osmosis_replication_base_url
    end

    return if hasproperty(header, :writingprogram) && header.writingprogram !== nothing
        osmdata.meta["writingprogram"] = header.writingprogram
    end
end

"""
    process_primitive_block!(osmdata, primblock, node_callback, way_callback, relation_callback)

Process a primitive block and extract nodes, ways, and relations.
Optimized for performance with efficient string table handling and batch processing.

# Arguments
- `osmdata::OpenStreetMap`: OSM data object to update
- `primblock::OSMPBF.PrimitiveBlock`: Primitive block from PBF file
- `node_callback::Union{Function,Nothing}`: Optional node filtering callback
- `way_callback::Union{Function,Nothing}`: Optional way filtering callback
- `relation_callback::Union{Function,Nothing}`: Optional relation filtering callback

# Internal function used by `readpbf`.
"""
function process_primitive_block!(
        osmdata::OpenStreetMap,
        primblock::OSMPBF.PrimitiveBlock,
        node_callback::Union{Function, Nothing},
        way_callback::Union{Function, Nothing},
        relation_callback::Union{Function, Nothing},
    )
    # Pre-compute string lookup table for performance
    string_table = build_string_table(primblock.stringtable)

    # Pre-compute lat/lon parameters for dense nodes
    latlon_params = LatLonParams(
        primblock.lat_offset, primblock.lon_offset, primblock.granularity
    )

    # Process each primitive group efficiently
    for primgrp in primblock.primitivegroup
        try
            # Extract regular nodes
            nodes = extract_regular_nodes(primgrp, string_table, node_callback)
            merge!(osmdata.nodes, nodes)

            # Extract dense nodes (more efficient format)
            if hasproperty(primgrp, :dense) && primgrp.dense !== nothing
                dense_nodes = extract_dense_nodes(
                    primgrp, string_table, latlon_params, node_callback
                )
                merge!(osmdata.nodes, dense_nodes)
            end

            # Extract ways
            ways = extract_ways(primgrp, string_table, way_callback)
            merge!(osmdata.ways, ways)

            # Extract relations
            relations = extract_relations(primgrp, string_table, relation_callback)
            merge!(osmdata.relations, relations)

        catch e
            @warn "Error processing primitive group: $e"
            continue  # Skip this group and continue with the next one
        end
    end
    return
end

# Helper struct for lat/lon parameters
struct LatLonParams
    lat_offset::Int64
    lon_offset::Int64
    granularity::Int64
end

"""
    build_string_table(stringtable)

Build an efficient string lookup table from the protobuf string table.
Optimized for performance with pre-allocated vector.

# Arguments
- `stringtable::OSMPBF.StringTable`: String table from protobuf

# Returns
- `Vector{String}`: Lookup table for string indices

# Internal function used by `process_primitive_block!`.
"""
function build_string_table(stringtable::OSMPBF.StringTable)::Vector{String}
    if isempty(stringtable.s)
        return String[]
    end

    # Pre-allocate vector for better performance
    string_table = Vector{String}(undef, length(stringtable.s))

    for (i, s) in enumerate(stringtable.s)
        try
            string_table[i] = Base.transcode(String, s)
        catch e
            @warn "Failed to transcode string at index $i: $e"
            string_table[i] = ""  # Use empty string as fallback
        end
    end

    return string_table
end

"""
    extract_regular_nodes(primgrp, string_table, node_callback)

Extract regular nodes from a primitive group.
Optimized for performance with efficient tag processing.

# Arguments
- `primgrp::OSMPBF.PrimitiveGroup`: Primitive group containing nodes
- `string_table::Vector{String}`: Pre-computed string lookup table
- `node_callback::Union{Function,Nothing}`: Optional node filtering callback

# Returns
- `Dict{Int64,Node}`: Extracted nodes

# Internal function used by `process_primitive_block!`.
"""
function extract_regular_nodes(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        node_callback::Union{Function, Nothing},
    )::Dict{Int64, Node}
    nodes = Dict{Int64, Node}()

    for n in primgrp.nodes
        try
            # Validate tag consistency
            if length(n.keys) != length(n.vals)
                @warn "Node $(n.id) has inconsistent tag keys/values, skipping"
                continue
            end

            # Build tags efficiently
            tags = nothing
            if length(n.keys) > 0
                tags = Dict{String, String}()
                for (k, v) in zip(n.keys, n.vals)
                    # Validate string indices
                    if k + 1 > length(string_table) || v + 1 > length(string_table)
                        @warn "Node $(n.id) has invalid string indices, skipping"
                        continue
                    end
                    tags[string_table[k + 1]] = string_table[v + 1]
                end
            end

            node = Node(LatLon(Float32(n.lat), Float32(n.lon)), tags)

            # Apply callback if provided
            if node_callback !== nothing
                cb_node = node_callback(node)
                if cb_node !== nothing
                    nodes[n.id] = cb_node
                end
            else
                nodes[n.id] = node
            end

        catch e
            @warn "Error processing node $(n.id): $e"
            continue
        end
    end

    return nodes
end

"""
    extract_dense_nodes(primgrp, string_table, latlon_params, node_callback)

Extract dense nodes from a primitive group.
Optimized for performance with vectorized operations and efficient tag processing.

# Arguments
- `primgrp::OSMPBF.PrimitiveGroup`: Primitive group containing dense nodes
- `string_table::Vector{String}`: Pre-computed string lookup table
- `latlon_params::LatLonParams`: Lat/lon conversion parameters
- `node_callback::Union{Function,Nothing}`: Optional node filtering callback

# Returns
- `Dict{Int64,Node}`: Extracted dense nodes

# Internal function used by `process_primitive_block!`.
"""
function extract_dense_nodes(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        latlon_params::LatLonParams,
        node_callback::Union{Function, Nothing},
    )::Dict{Int64, Node}
    if primgrp.dense === nothing || isempty(primgrp.dense.id)
        return Dict{Int64, Node}()
    end

    try
        # Compute cumulative IDs, lats, and lons efficiently
        ids = cumsum(primgrp.dense.id)
        lats =
            Float32.(
            round.(
                1.0e-9 * (
                    latlon_params.lat_offset .+
                        latlon_params.granularity .* cumsum(primgrp.dense.lat)
                ),
                digits = 7,
            )
        )
        lons =
            Float32.(
            round.(
                1.0e-9 * (
                    latlon_params.lon_offset .+
                        latlon_params.granularity .* cumsum(primgrp.dense.lon)
                ),
                digits = 7,
            )
        )

        # Validate data consistency
        if length(ids) != length(lats) || length(lats) != length(lons)
            @warn "Dense nodes have inconsistent ID/lat/lon lengths, skipping"
            return Dict{Int64, Node}()
        end

        # Extract tags efficiently
        tags = extract_dense_node_tags(primgrp.dense, string_table, ids)

        # Assemble Node objects
        nodes = Dict{Int64, Node}()
        for (id, lat, lon) in zip(ids, lats, lons)
            try
                node = Node(LatLon(lat, lon), get(tags, id, nothing))

                # Apply callback if provided
                if node_callback !== nothing
                    cb_node = node_callback(node)
                    if cb_node !== nothing
                        nodes[id] = cb_node
                    end
                else
                    nodes[id] = node
                end
            catch e
                @warn "Error processing dense node $id: $e"
                continue
            end
        end

        return nodes

    catch e
        @warn "Error processing dense nodes: $e"
        return Dict{Int64, Node}()
    end
end

"""
    extract_dense_node_tags(dense, string_table, ids)

Extract tags for dense nodes efficiently.
Optimized for performance with minimal allocations.

# Arguments
- `dense::OSMPBF.DenseNodes`: Dense nodes data
- `string_table::Vector{String}`: Pre-computed string lookup table
- `ids::Vector{Int64}`: Node IDs

# Returns
- `Dict{Int64,Dict{String,String}}`: Tags for each node ID

# Internal function used by `extract_dense_nodes`.
"""
function extract_dense_node_tags(
        dense::OSMPBF.DenseNodes, string_table::Vector{String}, ids::Vector{Int64}
    )::Dict{Int64, Dict{String, String}}
    tags = Dict{Int64, Dict{String, String}}()

    if isempty(dense.keys_vals)
        return tags
    end

    # Validate keys_vals ends with 0 (sentinel)
    if dense.keys_vals[end] != 0
        @warn "Dense nodes keys_vals doesn't end with sentinel 0, skipping tags"
        return tags
    end

    # Decode tags efficiently
    i = 1  # node index
    kv = 1  # key-value index

    while kv <= length(dense.keys_vals)
        k = dense.keys_vals[kv]

        if k == 0
            # Move to next node
            i += 1
            kv += 1
        else
            # Process current node's tag
            if kv >= length(dense.keys_vals)
                @warn "Dense nodes keys_vals truncated, skipping remaining tags"
                break
            end

            v = dense.keys_vals[kv + 1]

            # Validate string indices
            if k + 1 > length(string_table) || v + 1 > length(string_table)
                @warn "Dense node has invalid string indices, skipping tag"
                kv += 2
                continue
            end

            # Get node ID
            if i > length(ids)
                @warn "Dense node index out of bounds, skipping tag"
                kv += 2
                continue
            end

            id = ids[i]

            # Add tag
            if !haskey(tags, id)
                tags[id] = Dict{String, String}()
            end
            tags[id][string_table[k + 1]] = string_table[v + 1]

            kv += 2
        end
    end

    return tags
end

"""
    extract_ways(primgrp, string_table, way_callback)

Extract ways from a primitive group.
Optimized for performance with efficient tag processing and reference handling.

# Arguments
- `primgrp::OSMPBF.PrimitiveGroup`: Primitive group containing ways
- `string_table::Vector{String}`: Pre-computed string lookup table
- `way_callback::Union{Function,Nothing}`: Optional way filtering callback

# Returns
- `Dict{Int64,Way}`: Extracted ways

# Internal function used by `process_primitive_block!`.
"""
function extract_ways(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        way_callback::Union{Function, Nothing},
    )::Dict{Int64, Way}
    ways = Dict{Int64, Way}()

    for w in primgrp.ways
        try
            # Validate tag consistency
            if length(w.keys) != length(w.vals)
                @warn "Way $(w.id) has inconsistent tag keys/values, skipping"
                continue
            end

            # Build tags efficiently
            tags = nothing
            if length(w.keys) > 0
                tags = Dict{String, String}()
                for (k, v) in zip(w.keys, w.vals)
                    # Validate string indices
                    if k + 1 > length(string_table) || v + 1 > length(string_table)
                        @warn "Way $(w.id) has invalid string indices, skipping"
                        continue
                    end
                    tags[string_table[k + 1]] = string_table[v + 1]
                end
            end

            # Compute node references efficiently
            refs = cumsum(w.refs)

            way = Way(refs, tags)

            # Apply callback if provided
            if way_callback !== nothing
                cb_way = way_callback(way)
                if cb_way !== nothing
                    ways[w.id] = cb_way
                end
            else
                ways[w.id] = way
            end

        catch e
            @warn "Error processing way $(w.id): $e"
            continue
        end
    end

    return ways
end

"""
    extract_relations(primgrp, string_table, relation_callback)

Extract relations from a primitive group.
Optimized for performance with efficient tag processing and member handling.

# Arguments
- `primgrp::OSMPBF.PrimitiveGroup`: Primitive group containing relations
- `string_table::Vector{String}`: Pre-computed string lookup table
- `relation_callback::Union{Function,Nothing}`: Optional relation filtering callback

# Returns
- `Dict{Int64,Relation}`: Extracted relations

# Internal function used by `process_primitive_block!`.
"""
function extract_relations(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        relation_callback::Union{Function, Nothing},
    )::Dict{Int64, Relation}
    relations = Dict{Int64, Relation}()

    for r in primgrp.relations
        try
            # Validate tag consistency
            if length(r.keys) != length(r.vals)
                @warn "Relation $(r.id) has inconsistent tag keys/values, skipping"
                continue
            end

            # Build tags efficiently
            tags = nothing
            if length(r.keys) > 0
                tags = Dict{String, String}()
                for (k, v) in zip(r.keys, r.vals)
                    # Validate string indices
                    if k + 1 > length(string_table) || v + 1 > length(string_table)
                        @warn "Relation $(r.id) has invalid string indices, skipping"
                        continue
                    end
                    tags[string_table[k + 1]] = string_table[v + 1]
                end
            end

            # Compute member references and types efficiently
            refs = cumsum(r.memids)
            types = convert_member_types(r.types)
            roles = extract_relation_roles(r.roles_sid, string_table)

            relation = Relation(refs, types, roles, tags)

            # Apply callback if provided
            if relation_callback !== nothing
                cb_relation = relation_callback(relation)
                if cb_relation !== nothing
                    relations[r.id] = cb_relation
                end
            else
                relations[r.id] = relation
            end

        catch e
            @warn "Error processing relation $(r.id): $e"
            continue
        end
    end

    return relations
end

"""
    convert_member_types(types)

Convert protobuf member type enums to strings efficiently.
Handles both integer and enum types from protobuf.

# Arguments
- `types`: Member type enums or integers from protobuf

# Returns
- `Vector{String}`: Member type strings

# Internal function used by `extract_relations`.
"""
function convert_member_types(types)::Vector{String}
    result = Vector{String}(undef, length(types))

    for (i, t) in enumerate(types)
        try
            # Convert to integer first, then handle
            t_int = Int(t)
            if t_int == 0
                result[i] = "node"
            elseif t_int == 1
                result[i] = "way"
            elseif t_int == 2
                result[i] = "relation"
            else
                @warn "Unknown member type $t (int: $t_int), defaulting to 'node'"
                result[i] = "node"
            end
        catch e
            @warn "Error converting member type $t: $e, defaulting to 'node'"
            result[i] = "node"
        end
    end

    return result
end

"""
    extract_relation_roles(roles_sid, string_table)

Extract relation member roles from string indices efficiently.

# Arguments
- `roles_sid::Vector{Int32}`: Role string indices from protobuf
- `string_table::Vector{String}`: Pre-computed string lookup table

# Returns
- `Vector{String}`: Role strings

# Internal function used by `extract_relations`.
"""
function extract_relation_roles(
        roles_sid::Vector{Int32}, string_table::Vector{String}
    )::Vector{String}
    result = Vector{String}(undef, length(roles_sid))

    for (i, sid) in enumerate(roles_sid)
        if sid + 1 > length(string_table)
            @warn "Invalid role string index $sid, using empty string"
            result[i] = ""
        else
            result[i] = string_table[sid + 1]
        end
    end

    return result
end
