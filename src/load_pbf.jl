import ProtoBuf
using ProtoBuf: decode, ProtoDecoder, PipeBuffer
import CodecZlib
using Dates: DateTime, Millisecond, unix2datetime
using Lz4_jll: liblz4
using XZ_jll: liblzma
using Zstd_jll: libzstd

const NANODEG_TO_DEG = 1.0e-9
const LZMA_OK = Cint(0)
const LZMA_STREAM_END = Cint(1)
const _TS = CodecZlib.TranscodingStreams

struct LatLonParams
    lat_offset::Int64
    lon_offset::Int64
    granularity::Int64
    date_granularity::Int64
end

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
"""
function readpbf(
        filename::String;
        node_callback::Union{Function, Nothing} = nothing,
        way_callback::Union{Function, Nothing} = nothing,
        relation_callback::Union{Function, Nothing} = nothing,
    )::OpenStreetMap
    isfile(filename) || throw(ArgumentError("File '$filename' does not exist"))

    osmdata = OpenStreetMap()

    try
        open(filename, "r") do io
            blobheader, blob = read_next_blob(io)
            validate_blob_type(blobheader, "OSMHeader")

            header_block = decode_blob(blob, OSMPBF.HeaderBlock)
            process_header_block!(osmdata, header_block)

            while !eof(io)
                blobheader, blob = read_next_blob(io)
                validate_blob_type(blobheader, "OSMData")

                primitive_block = decode_blob(blob, OSMPBF.PrimitiveBlock)
                process_primitive_block!(
                    osmdata,
                    primitive_block,
                    node_callback,
                    way_callback,
                    relation_callback,
                )
            end
        end
    catch err
        if isa(err, SystemError)
            throw(ArgumentError("Cannot read file '$filename': $(err.msg)"))
        else
            rethrow(err)
        end
    end

    return osmdata
end

function read_next_blob(io)::Tuple{OSMPBF.BlobHeader, OSMPBF.Blob}
    header_size_bytes = read(io, UInt32)
    eof(io) && throw(EOFError("Unexpected end of file while reading blob header size"))

    header_size = ntoh(header_size_bytes)
    header_size > 64 * 1024 &&
        throw(ArgumentError("Blob header size too large: $header_size bytes"))

    header_data = read(io, header_size)
    eof(io) && throw(EOFError("Unexpected end of file while reading blob header"))

    blobheader = decode(ProtoDecoder(PipeBuffer(header_data)), OSMPBF.BlobHeader)

    blobheader.datasize > 32 * 1024 * 1024 &&
        throw(ArgumentError("Blob data size too large: $(blobheader.datasize) bytes"))

    blob_data = read(io, blobheader.datasize)
    length(blob_data) != blobheader.datasize && throw(EOFError("Incomplete blob data read"))

    blob = decode(ProtoDecoder(PipeBuffer(blob_data)), OSMPBF.Blob)

    return blobheader, blob
end

function validate_blob_type(blobheader::OSMPBF.BlobHeader, expected_type::String)
    actual_type = blobheader.var"#type"
    if actual_type != expected_type
        throw(ArgumentError("Expected blob type '$expected_type', got '$actual_type'"))
    end
    return
end

function decode_blob(
        blob::OSMPBF.Blob,
        block_type::Union{Type{OSMPBF.HeaderBlock}, Type{OSMPBF.PrimitiveBlock}},
    )
    payload, format = blob_payload(blob)
    isempty(payload) && throw(ArgumentError("Blob contains no data"))

    buffer = decompress_blob(payload, format, Int(blob.raw_size))

    return try
        decode(ProtoDecoder(PipeBuffer(buffer)), block_type)
    catch err
        if isa(err, ProtoBuf.ProtoError)
            throw(ArgumentError("Failed to decode blob: $(err.msg)"))
        else
            rethrow(err)
        end
    end
end

function blob_payload(blob::OSMPBF.Blob)::Tuple{Vector{UInt8}, Symbol}
    blob.data === nothing && return UInt8[], :none
    return blob.data[], blob.data.name
end

function decompress_blob(data::Vector{UInt8}, format::Symbol, raw_size::Int)
    if format === :raw
        return data
    elseif format === :zlib_data
        return _TS.transcode(CodecZlib.ZlibDecompressor, data)
    elseif format === :lz4_data
        return decompress_lz4(data, raw_size)
    elseif format === :zstd_data
        return decompress_zstd(data, raw_size)
    elseif format === :lzma_data
        return decompress_lzma(data, raw_size)
    elseif format === :OBSOLETE_bzip2_data
        throw(ArgumentError("bzip2 blobs are deprecated and unsupported"))
    else
        throw(ArgumentError("Unsupported blob compression format '$format'"))
    end
end

function process_header_block!(osmdata::OpenStreetMap, header::OSMPBF.HeaderBlock)
    if hasproperty(header, :bbox) && header.bbox !== nothing
        bbox = header.bbox
        try
            osmdata.meta["bbox"] = BBox(
                Float32(round(NANODEG_TO_DEG * bbox.bottom; digits = 7)),
                Float32(round(NANODEG_TO_DEG * bbox.left; digits = 7)),
                Float32(round(NANODEG_TO_DEG * bbox.top; digits = 7)),
                Float32(round(NANODEG_TO_DEG * bbox.right; digits = 7)),
            )
        catch err
            @warn "Invalid bounding box in header" err
        end
    end

    if hasproperty(header, :required_features) && !isempty(header.required_features)
        osmdata.meta["required_features"] = copy(header.required_features)
    end
    if hasproperty(header, :optional_features) && !isempty(header.optional_features)
        osmdata.meta["optional_features"] = copy(header.optional_features)
    end

    if hasproperty(header, :source) && !isempty(header.source)
        osmdata.meta["source"] = header.source
    end
    if hasproperty(header, :writingprogram) && !isempty(header.writingprogram)
        osmdata.meta["writingprogram"] = header.writingprogram
    end

    if hasproperty(header, :osmosis_replication_timestamp) &&
            header.osmosis_replication_timestamp !== nothing &&
            header.osmosis_replication_timestamp != 0
        try
            osmdata.meta["replication_timestamp"] = unix2datetime(header.osmosis_replication_timestamp)
        catch err
            @warn "Invalid timestamp in header" err
        end
    end

    if hasproperty(header, :osmosis_replication_sequence_number) &&
            header.osmosis_replication_sequence_number !== nothing &&
            header.osmosis_replication_sequence_number != 0
        osmdata.meta["replication_sequence_number"] = header.osmosis_replication_sequence_number
    end

    if hasproperty(header, :osmosis_replication_base_url) &&
            header.osmosis_replication_base_url !== nothing &&
            !isempty(header.osmosis_replication_base_url)
        osmdata.meta["replication_base_url"] = header.osmosis_replication_base_url
    end

    return
end

function process_primitive_block!(
        osmdata::OpenStreetMap,
        primblock::OSMPBF.PrimitiveBlock,
        node_callback::Union{Function, Nothing},
        way_callback::Union{Function, Nothing},
        relation_callback::Union{Function, Nothing},
    )
    string_table = build_string_table(primblock.stringtable)
    date_granularity = hasproperty(primblock, :date_granularity) && primblock.date_granularity != 0 ?
        Int64(primblock.date_granularity) : Int64(1_000)
    params = LatLonParams(
        primblock.lat_offset,
        primblock.lon_offset,
        primblock.granularity,
        date_granularity,
    )

    for primgrp in primblock.primitivegroup
        try
            nodes = extract_regular_nodes(primgrp, string_table, params, node_callback)
            merge!(osmdata.nodes, nodes)

            if hasproperty(primgrp, :dense) && primgrp.dense !== nothing && !isempty(primgrp.dense.id)
                dense_nodes = extract_dense_nodes(primgrp, string_table, params, node_callback)
                merge!(osmdata.nodes, dense_nodes)
            end

            ways = extract_ways(primgrp, string_table, params, way_callback)
            merge!(osmdata.ways, ways)

            relations = extract_relations(primgrp, string_table, params, relation_callback)
            merge!(osmdata.relations, relations)
        catch err
            @warn "Error processing primitive group" err
        end
    end

    return
end

function build_string_table(stringtable::OSMPBF.StringTable)::Vector{String}
    if isempty(stringtable.s)
        return String[]
    end

    table = Vector{String}(undef, length(stringtable.s))
    for (idx, bytes) in enumerate(stringtable.s)
        try
            table[idx] = String(copy(bytes))
        catch err
            @warn "Failed to transcode string table entry" idx err
            table[idx] = ""
        end
    end
    return table
end

@inline function decode_coordinate(raw::Int64, offset::Int64, granularity::Int64)::Float32
    value = NANODEG_TO_DEG * (offset + granularity * raw)
    return Float32(round(value; digits = 7))
end

@inline function decode_timestamp(raw::Int64, date_granularity::Int64)
    raw == 0 && return nothing
    millis = raw * date_granularity
    seconds = fld(millis, 1_000)
    remainder = millis - seconds * 1_000
    return unix2datetime(seconds) + Millisecond(remainder)
end

@inline function string_from_sid(sid::Integer, table::Vector{String})
    sid < 0 && return nothing
    index = Int(sid) + 1
    (1 <= index <= length(table)) || return nothing
    value = table[index]
    isempty(value) && return nothing
    return value
end

function build_metadata(
        info::Union{Nothing, OSMPBF.Info},
        string_table::Vector{String},
        params::LatLonParams,
    )
    info === nothing && return nothing

    version = info.version == Int32(-1) ? nothing : info.version
    timestamp = decode_timestamp(Int64(info.timestamp), params.date_granularity)
    changeset = info.changeset == 0 ? nothing : Int64(info.changeset)
    uid = info.uid == 0 ? nothing : info.uid
    user = string_from_sid(info.user_sid, string_table)
    visible = info.visible

    if version === nothing && timestamp === nothing && changeset === nothing &&
            uid === nothing && user === nothing && visible === nothing
        return nothing
    end

    return ElementMetadata(version, timestamp, changeset, uid, user, visible)
end

function dense_metadata_field(values, default, count; delta::Bool = false)
    if isempty(values)
        return fill(default, count)
    end

    data = delta ? cumsum(values) : copy(values)
    if length(data) < count
        append!(data, fill(default, count - length(data)))
    elseif length(data) > count
        resize!(data, count)
    end
    return data
end

function build_dense_metadata(
        dense::OSMPBF.DenseNodes,
        string_table::Vector{String},
        params::LatLonParams,
        ids::Vector{Int64},
    )
    dense.denseinfo === nothing && return Dict{Int64, ElementMetadata}()
    info = dense.denseinfo
    count = length(ids)

    versions = dense_metadata_field(info.version, Int32(-1), count)
    timestamps = dense_metadata_field(info.timestamp, 0, count; delta = true)
    changesets = dense_metadata_field(info.changeset, 0, count; delta = true)
    uids = dense_metadata_field(info.uid, Int32(0), count; delta = true)
    user_sids = dense_metadata_field(info.user_sid, Int32(0), count; delta = true)
    visibles = dense_metadata_field(info.visible, true, count)

    metadata = Dict{Int64, ElementMetadata}()
    for (idx, id) in enumerate(ids)
        version = versions[idx] == Int32(-1) ? nothing : versions[idx]
        timestamp = decode_timestamp(Int64(timestamps[idx]), params.date_granularity)
        changeset = changesets[idx] == 0 ? nothing : Int64(changesets[idx])
        uid = uids[idx] == 0 ? nothing : uids[idx]
        user = string_from_sid(user_sids[idx], string_table)
        visible = visibles[idx]
        metadata[id] = ElementMetadata(version, timestamp, changeset, uid, user, visible)
    end

    return metadata
end

function build_tags(
        keys::Vector{UInt32},
        vals::Vector{UInt32},
        string_table::Vector{String},
        element_id::Int64,
        element_type::String,
    )
    isempty(keys) && return nothing
    length(keys) == length(vals) || begin
        @warn "$element_type $element_id has inconsistent tag keys/values"
        return nothing
    end

    tags = Dict{String, String}()
    for (k, v) in zip(keys, vals)
        key = string_from_sid(k, string_table)
        value = string_from_sid(v, string_table)
        if key === nothing || value === nothing
            @warn "$element_type $element_id has invalid string indices, skipping"
            continue
        end
        tags[key] = value
    end

    return isempty(tags) ? nothing : tags
end

function extract_regular_nodes(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        params::LatLonParams,
        node_callback::Union{Function, Nothing},
    )::Dict{Int64, Node}
    nodes = Dict{Int64, Node}()

    for n in primgrp.nodes
        try
            tags = build_tags(n.keys, n.vals, string_table, n.id, "Node")
            lat = decode_coordinate(n.lat, params.lat_offset, params.granularity)
            lon = decode_coordinate(n.lon, params.lon_offset, params.granularity)
            metadata = hasproperty(n, :info) && n.info !== nothing ?
                build_metadata(n.info, string_table, params) : nothing

            candidate = Node(LatLon(lat, lon), tags, metadata)

            if node_callback !== nothing
                filtered = node_callback(candidate)
                filtered !== nothing && (nodes[n.id] = filtered)
            else
                nodes[n.id] = candidate
            end
        catch err
            @warn "Error processing node $(n.id)" err
        end
    end

    return nodes
end

function extract_dense_nodes(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        params::LatLonParams,
        node_callback::Union{Function, Nothing},
    )::Dict{Int64, Node}
    dense = primgrp.dense
    (dense === nothing || isempty(dense.id)) && return Dict{Int64, Node}()

    try
        ids = cumsum(dense.id)
        lat_raw = cumsum(dense.lat)
        lon_raw = cumsum(dense.lon)

        if length(lat_raw) != length(lon_raw)
            @warn "Dense nodes have inconsistent coordinate lengths, skipping"
            return Dict{Int64, Node}()
        end

        lats = decode_coordinate.(lat_raw, Ref(params.lat_offset), Ref(params.granularity))
        lons = decode_coordinate.(lon_raw, Ref(params.lon_offset), Ref(params.granularity))

        tags_by_id = extract_dense_node_tags(dense, string_table, ids)
        metadata_by_id = build_dense_metadata(dense, string_table, params, ids)

        nodes = Dict{Int64, Node}()
        for (idx, id) in enumerate(ids)
            try
                candidate = Node(
                    LatLon(lats[idx], lons[idx]),
                    get(tags_by_id, id, nothing),
                    get(metadata_by_id, id, nothing),
                )

                if node_callback !== nothing
                    filtered = node_callback(candidate)
                    filtered !== nothing && (nodes[id] = filtered)
                else
                    nodes[id] = candidate
                end
            catch err
                @warn "Error processing dense node $id" err
            end
        end

        return nodes
    catch err
        @warn "Error processing dense nodes" err
        return Dict{Int64, Node}()
    end
end

function extract_dense_node_tags(
        dense::OSMPBF.DenseNodes, string_table::Vector{String}, ids::Vector{Int64}
    )::Dict{Int64, Dict{String, String}}
    tags = Dict{Int64, Dict{String, String}}()

    if isempty(dense.keys_vals)
        return tags
    end

    if dense.keys_vals[end] != 0
        @warn "Dense nodes keys_vals doesn't end with sentinel 0, skipping tags"
        return tags
    end

    node_index = 1
    kv_index = 1

    while kv_index <= length(dense.keys_vals)
        key_sid = dense.keys_vals[kv_index]

        if key_sid == 0
            node_index += 1
            kv_index += 1
            continue
        end

        kv_index + 1 > length(dense.keys_vals) && break
        value_sid = dense.keys_vals[kv_index + 1]

        if node_index > length(ids)
            @warn "Dense node index out of bounds, skipping tag"
            kv_index += 2
            continue
        end

        key = string_from_sid(key_sid, string_table)
        value = string_from_sid(value_sid, string_table)
        if key !== nothing && value !== nothing
            dict = get!(tags, ids[node_index], Dict{String, String}())
            dict[key] = value
        end

        kv_index += 2
    end

    return tags
end

function decode_way_coordinates(way::OSMPBF.Way, params::LatLonParams)
    isempty(way.lat) && return nothing
    if length(way.lat) != length(way.lon)
        @warn "Way $(way.id) has inconsistent embedded coordinates"
        return nothing
    end

    lat_raw = cumsum(way.lat)
    lon_raw = cumsum(way.lon)
    coords = Vector{LatLon}(undef, length(lat_raw))
    for idx in eachindex(lat_raw)
        lat = decode_coordinate(lat_raw[idx], params.lat_offset, params.granularity)
        lon = decode_coordinate(lon_raw[idx], params.lon_offset, params.granularity)
        coords[idx] = LatLon(lat, lon)
    end
    return coords
end

function extract_ways(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        params::LatLonParams,
        way_callback::Union{Function, Nothing},
    )::Dict{Int64, Way}
    ways = Dict{Int64, Way}()

    for w in primgrp.ways
        try
            tags = build_tags(w.keys, w.vals, string_table, w.id, "Way")
            refs = cumsum(w.refs)
            metadata = hasproperty(w, :info) && w.info !== nothing ?
                build_metadata(w.info, string_table, params) : nothing
            coordinates = decode_way_coordinates(w, params)

            candidate = Way(refs, tags, metadata, coordinates)

            if way_callback !== nothing
                filtered = way_callback(candidate)
                filtered !== nothing && (ways[w.id] = filtered)
            else
                ways[w.id] = candidate
            end
        catch err
            @warn "Error processing way $(w.id)" err
        end
    end

    return ways
end

function extract_relations(
        primgrp::OSMPBF.PrimitiveGroup,
        string_table::Vector{String},
        params::LatLonParams,
        relation_callback::Union{Function, Nothing},
    )::Dict{Int64, Relation}
    relations = Dict{Int64, Relation}()

    for r in primgrp.relations
        try
            tags = build_tags(r.keys, r.vals, string_table, r.id, "Relation")
            refs = cumsum(r.memids)
            types = convert_member_types(r.types)
            roles = extract_relation_roles(r.roles_sid, string_table)
            metadata = hasproperty(r, :info) && r.info !== nothing ?
                build_metadata(r.info, string_table, params) : nothing

            candidate = Relation(refs, types, roles, tags, metadata)

            if relation_callback !== nothing
                filtered = relation_callback(candidate)
                filtered !== nothing && (relations[r.id] = filtered)
            else
                relations[r.id] = candidate
            end
        catch err
            @warn "Error processing relation $(r.id)" err
        end
    end

    return relations
end

function convert_member_types(types)::Vector{String}
    result = Vector{String}(undef, length(types))

    for (idx, value) in enumerate(types)
        val = Int(value)
        if val == 0
            result[idx] = "node"
        elseif val == 1
            result[idx] = "way"
        elseif val == 2
            result[idx] = "relation"
        else
            @warn "Unknown relation member type $value"
            result[idx] = "node"
        end
    end

    return result
end

function extract_relation_roles(
        roles_sid::Vector{Int32}, string_table::Vector{String}
    )::Vector{String}
    roles = Vector{String}(undef, length(roles_sid))
    for (idx, sid) in enumerate(roles_sid)
        role = string_from_sid(sid, string_table)
        roles[idx] = role === nothing ? "" : role
    end
    return roles
end

function decompress_lz4(data::Vector{UInt8}, raw_size::Int)
    raw_size > 0 || throw(ArgumentError("LZ4 blob missing raw_size"))
    output = Vector{UInt8}(undef, raw_size)
    result = ccall(
        (:LZ4_decompress_safe, liblz4), Cint,
        (Ptr{UInt8}, Ptr{UInt8}, Cint, Cint),
        pointer(data), pointer(output), Cint(length(data)), Cint(length(output)),
    )
    result < 0 && throw(ArgumentError("LZ4 decompression failed with code $result"))
    result != raw_size && resize!(output, result)
    return output
end

function zstd_content_size(data::Vector{UInt8})
    size = ccall((:ZSTD_getFrameContentSize, libzstd), UInt64, (Ptr{UInt8}, Csize_t), pointer(data), Csize_t(length(data)))
    size == UInt64(0xFFFFFFFFFFFFFFFF) && return nothing
    size == UInt64(0xFFFFFFFFFFFFFFFE) && return nothing
    return Int(size)
end

function decompress_zstd(data::Vector{UInt8}, raw_size::Int)
    size_hint = raw_size > 0 ? raw_size : zstd_content_size(data)
    size_hint === nothing && throw(ArgumentError("Unable to determine ZSTD output size"))
    output = Vector{UInt8}(undef, size_hint)
    result = ccall(
        (:ZSTD_decompress, libzstd), Csize_t,
        (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Csize_t),
        pointer(output), Csize_t(length(output)), pointer(data), Csize_t(length(data)),
    )
    if ccall((:ZSTD_isError, libzstd), UInt32, (Csize_t,), result) != 0
        err_ptr = ccall((:ZSTD_getErrorName, libzstd), Ptr{UInt8}, (Csize_t,), result)
        throw(ArgumentError("ZSTD decompression failed: $(unsafe_string(err_ptr))"))
    end
    resize!(output, Int(result))
    return output
end

function decompress_lzma(data::Vector{UInt8}, raw_size::Int)
    raw_size > 0 || throw(ArgumentError("LZMA blob missing raw_size"))
    output = Vector{UInt8}(undef, raw_size)
    memlimit = Ref{UInt64}(0)
    in_pos = Ref{Csize_t}(0)
    out_pos = Ref{Csize_t}(0)
    ret = ccall(
        (:lzma_stream_buffer_decode, liblzma), Cint,
        (
            Ref{UInt64}, UInt32, Ptr{Nothing}, Ptr{UInt8}, Ref{Csize_t}, Csize_t,
            Ptr{UInt8}, Ref{Csize_t}, Csize_t,
        ),
        memlimit, UInt32(0), C_NULL,
        pointer(data), in_pos, Csize_t(length(data)),
        pointer(output), out_pos, Csize_t(length(output)),
    )
    if ret != LZMA_OK && ret != LZMA_STREAM_END
        throw(ArgumentError("LZMA decompression failed with code $ret"))
    end
    resize!(output, Int(out_pos[]))
    return output
end
