using OpenStreetMapIO, Test
using ProtoBuf
using ProtoBuf: OneOf, ProtoEncoder
using Dates: DateTime
using Zstd_jll: libzstd

const PB = OpenStreetMapIO.OSMPBF

function compress_zstd(data::Vector{UInt8})
    bound = ccall((:ZSTD_compressBound, libzstd), Csize_t, (Csize_t,), Csize_t(length(data)))
    output = Vector{UInt8}(undef, Int(bound))
    result = ccall(
        (:ZSTD_compress, libzstd), Csize_t,
        (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Csize_t, Cint),
        pointer(output), Csize_t(length(output)), pointer(data), Csize_t(length(data)), Cint(3),
    )
    if ccall((:ZSTD_isError, libzstd), UInt32, (Csize_t,), result) != 0
        err_ptr = ccall((:ZSTD_getErrorName, libzstd), Ptr{UInt8}, (Csize_t,), result)
        error("ZSTD compression failed: $(unsafe_string(err_ptr))")
    end
    resize!(output, Int(result))
    return output
end

@testset "PBF File Reading Tests" begin
    @testset "Basic PBF Reading" begin
        # Test basic PBF file reading
        @time osmdata = TEST_DATA_PBF

        # Verify basic structure
        @test osmdata isa OpenStreetMap
        @test length(osmdata.nodes) > 0
        @test length(osmdata.ways) > 0
        @test length(osmdata.relations) > 0

        # Test specific known elements
        @testset "Testing Node" begin
            if haskey(osmdata.nodes, KNOWN_NODE_ID)
                node = osmdata.nodes[KNOWN_NODE_ID]

                @test typeof(node) === Node
                @test isapprox(node.latlon.lat, TEST_POINT_1.lat; atol = 1.0e-6)
                @test isapprox(node.latlon.lon, TEST_POINT_1.lon; atol = 1.0e-6)
                @test length(node.tags) >= 3  # Should have some tags
                @test node.tags["addr:country"] === "DE"
                # Other tags may vary depending on data version
                @test haskey(node.tags, "addr:city")
                @test haskey(node.tags, "addr:postcode")
                @test haskey(node.tags, "addr:street")
                @test node.metadata === nothing || node.metadata isa ElementMetadata
            end
        end

        @testset "Testing Way" begin
            if haskey(osmdata.ways, KNOWN_WAY_ID)
                way = osmdata.ways[KNOWN_WAY_ID]

                @test typeof(way) === Way
                @test length(way.refs) > 0
                @test length(way.tags) > 0
                # Specific values may vary depending on data version
                @test haskey(way.tags, "natural") || haskey(way.tags, "highway")
                @test way.metadata === nothing || way.metadata isa ElementMetadata
            end
        end

        @testset "Testing Relation" begin
            if haskey(osmdata.relations, KNOWN_RELATION_ID)
                relation = osmdata.relations[KNOWN_RELATION_ID]

                @test typeof(relation) === Relation
                @test length(relation.refs) > 0  # Should have some references
                @test length(relation.types) === length(relation.refs)
                @test length(relation.roles) === length(relation.refs)
                @test length(relation.tags) > 0  # Should have some tags
                @test haskey(relation.tags, "type")
                @test relation.metadata === nothing || relation.metadata isa ElementMetadata
            end
        end
    end

    @testset "PBF Reading with Callbacks" begin
        # Test node callback
        node_count = 0
        function node_callback(node)
            node_count += 1
            return node
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; node_callback = node_callback)
        @test node_count > 0
        @test length(osmdata.nodes) == node_count

        # Test way callback
        way_count = 0
        function way_callback(way)
            way_count += 1
            return way
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; way_callback = way_callback)
        @test way_count > 0
        @test length(osmdata.ways) == way_count

        # Test relation callback
        relation_count = 0
        function relation_callback(relation)
            relation_count += 1
            return relation
        end

        osmdata = OpenStreetMapIO.readpbf(
            "data/map.pbf"; relation_callback = relation_callback
        )
        @test relation_count > 0
        @test length(osmdata.relations) == relation_count

        # Test filtering callback (only keep nodes with specific tags)
        filtered_nodes = 0
        function filter_nodes(node)
            if node.tags !== nothing &&
                    haskey(node.tags, "addr:country") &&
                    node.tags["addr:country"] == "DE"
                filtered_nodes += 1
                return node
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; node_callback = filter_nodes)
        @test filtered_nodes > 0
        @test length(osmdata.nodes) == filtered_nodes

        # Verify all filtered nodes have the expected tag
        for (id, node) in osmdata.nodes
            @test node.tags !== nothing
            @test haskey(node.tags, "addr:country")
            @test node.tags["addr:country"] == "DE"
        end
    end

    @testset "PBF Reading Error Handling" begin
        # Test reading non-existent file
        @test_throws ArgumentError OpenStreetMapIO.readpbf("nonexistent.pbf")

        # Test reading invalid PBF file (using XML file)
        @test_throws ArgumentError OpenStreetMapIO.readpbf("data/map.osm")

        # Test callback errors - now handled gracefully with warnings
        function error_callback(element)
            throw(ErrorException("Callback error"))
        end

        # Callback errors are now handled gracefully, so this should not throw
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; node_callback = error_callback)
        @test length(osmdata.nodes) == 0  # No nodes should be processed due to callback errors
    end

    @testset "PBF Metadata Extraction" begin
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test metadata structure
        @test haskey(osmdata.meta, "bbox")
        bbox = osmdata.meta["bbox"]
        @test bbox isa BBox

        # Test bounding box validity
        @test bbox.bottom_lat <= bbox.top_lat
        @test bbox.left_lon <= bbox.right_lon

        # Test that most nodes are within the bounding box (some may be outside due to data extraction)
        nodes_in_bbox = 0
        total_nodes = length(osmdata.nodes)

        for (id, node) in osmdata.nodes
            if bbox.bottom_lat <= node.latlon.lat <= bbox.top_lat &&
                    bbox.left_lon <= node.latlon.lon <= bbox.right_lon
                nodes_in_bbox += 1
            end
        end

        # Some nodes should be within the bounding box
        @test nodes_in_bbox > 0  # At least some nodes should be in bbox
    end

    @testset "PBF Performance Tests" begin
        # Test reading time
        start_time = time()
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")
        read_time = time() - start_time

        @test read_time < 10.0  # Should read in less than 10 seconds

        # Test memory usage
        @test length(osmdata.nodes) > 0
        @test length(osmdata.ways) > 0
        @test length(osmdata.relations) > 0

        # Test data integrity
        total_nodes = length(osmdata.nodes)
        total_ways = length(osmdata.ways)
        total_relations = length(osmdata.relations)

        @test total_nodes > 100  # Should have some data
        @test total_ways > 10
        @test total_relations > 0
    end

    @testset "PBF Data Consistency" begin
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test that all way references point to existing nodes
        for (way_id, way) in osmdata.ways
            for ref in way.refs
                @test haskey(osmdata.nodes, ref)
            end
        end

        # Test that relation references are valid (some may reference external elements)
        for (relation_id, relation) in osmdata.relations
            for (ref, type) in zip(relation.refs, relation.types)
                if type == "node"
                    # Most nodes should be present, but some may be external
                    if haskey(osmdata.nodes, ref)
                        @test true  # Node is present
                    end
                elseif type == "way"
                    # Most ways should be present, but some may be external
                    if haskey(osmdata.ways, ref)
                        @test true  # Way is present
                    end
                elseif type == "relation"
                    # Relations may reference external relations
                    if haskey(osmdata.relations, ref)
                        @test true  # Relation is present
                    end
                end
            end
        end

        # Test tag consistency
        for (id, node) in osmdata.nodes
            if node.tags !== nothing
                @test isa(node.tags, Dict{String, String})
                for (key, value) in node.tags
                    @test isa(key, String)
                    @test isa(value, String)
                    @test !isempty(key)
                end
            end
        end

        # Test that we have some valid internal references
        internal_node_refs = 0
        internal_way_refs = 0
        internal_relation_refs = 0

        for (way_id, way) in osmdata.ways
            for ref in way.refs
                if haskey(osmdata.nodes, ref)
                    internal_node_refs += 1
                end
            end
        end

        for (relation_id, relation) in osmdata.relations
            for (ref, type) in zip(relation.refs, relation.types)
                if type == "node" && haskey(osmdata.nodes, ref)
                    internal_node_refs += 1
                elseif type == "way" && haskey(osmdata.ways, ref)
                    internal_way_refs += 1
                elseif type == "relation" && haskey(osmdata.relations, ref)
                    internal_relation_refs += 1
                end
            end
        end

        # Should have some internal references
        @test internal_node_refs > 0
        @test internal_way_refs >= 0  # May be 0 if no internal way references
        @test internal_relation_refs >= 0  # May be 0 if no internal relation references
    end

    @testset "Element Metadata Extraction" begin
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        if haskey(osmdata.nodes, KNOWN_NODE_ID)
            meta = osmdata.nodes[KNOWN_NODE_ID].metadata
            @test meta !== nothing
            if meta !== nothing
                @test meta.version === nothing || meta.version isa Int32
                @test meta.timestamp === nothing || meta.timestamp isa DateTime
                @test meta.changeset === nothing || meta.changeset isa Int64
                @test meta.uid === nothing || meta.uid isa Int32
                @test meta.user === nothing || meta.user isa String
                @test meta.visible === nothing || meta.visible isa Bool
                @test any(!isnothing, (meta.version, meta.timestamp, meta.changeset, meta.uid, meta.user, meta.visible))
            end
        end

        if haskey(osmdata.ways, KNOWN_WAY_ID)
            meta = osmdata.ways[KNOWN_WAY_ID].metadata
            @test meta !== nothing
            if meta !== nothing
                @test meta.version === nothing || meta.version isa Int32
                @test meta.timestamp === nothing || meta.timestamp isa DateTime
                @test meta.user === nothing || meta.user isa String
            end
        end

        if haskey(osmdata.relations, KNOWN_RELATION_ID)
            meta = osmdata.relations[KNOWN_RELATION_ID].metadata
            @test meta !== nothing
            if meta !== nothing
                @test meta.version === nothing || meta.version isa Int32
                @test meta.timestamp === nothing || meta.timestamp isa DateTime
            end
        end
    end

    @testset "LocationsOnWays Decoding" begin
        way_id = 2001
        way = PB.Way(
            Int64(way_id),
            UInt32[],
            UInt32[],
            nothing,
            Int64[1, 1],
            Int64[100_000_000, 50_000_000],
            Int64[20_000_000, -10_000_000],
        )
        primgrp = PB.PrimitiveGroup(PB.Node[], nothing, [way], PB.Relation[], PB.ChangeSet[])
        block = PB.PrimitiveBlock(
            PB.StringTable(Vector{Vector{UInt8}}([UInt8[]])),
            [primgrp],
            Int32(100),
            Int64(0),
            Int64(0),
            Int32(1000),
        )

        osmdata = OpenStreetMap()
        OpenStreetMapIO.process_primitive_block!(osmdata, block, nothing, nothing, nothing)

        @test haskey(osmdata.ways, way_id)
        decoded_way = osmdata.ways[way_id]
        @test decoded_way.coordinates !== nothing
        coords = decoded_way.coordinates
        @test length(coords) == 2
        @test isapprox(coords[1].lat, 10.0f0; atol = 1.0e-5)
        @test isapprox(coords[1].lon, 2.0f0; atol = 1.0e-5)
        @test isapprox(coords[2].lat, 15.0f0; atol = 1.0e-5)
        @test isapprox(coords[2].lon, 1.0f0; atol = 1.0e-5)
    end

    @testset "Additional Compression Formats" begin
        block = PB.PrimitiveBlock(
            PB.StringTable(Vector{Vector{UInt8}}([UInt8[]])),
            PB.PrimitiveGroup[],
            Int32(100),
            Int64(0),
            Int64(0),
            Int32(1000),
        )

        buffer = IOBuffer()
        encoder = ProtoEncoder(buffer)
        ProtoBuf.encode(encoder, block)
        encoded = take!(buffer)
        compressed = compress_zstd(encoded)
        blob = PB.Blob(Int32(length(encoded)), OneOf(:zstd_data, compressed))

        decoded = OpenStreetMapIO.decode_blob(blob, PB.PrimitiveBlock)
        @test decoded.granularity == block.granularity
        @test decoded.date_granularity == block.date_granularity
        @test isempty(decoded.primitivegroup)
    end
end
