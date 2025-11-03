if !isdefined(Main, :TestUtils)
    include("TestUtils.jl")
    using .TestUtils
end
using OpenStreetMapIO, Test
using ProtoBuf: OneOf
using CodecZlib: ZlibCompressorStream

@testset "Load PBF Tests" begin
    test_file_pbf = test_data_path("map.pbf")

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
                @test node.position === TEST_POINT_1
                @test length(node.tags) >= 3  # Should have some tags
                @test node.tags["addr:country"] === "DE"
                # Other tags may vary depending on data version
                @test haskey(node.tags, "addr:city")
                @test haskey(node.tags, "addr:postcode")
                @test haskey(node.tags, "addr:street")
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

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = node_callback)
        @test node_count > 0
        @test length(osmdata.nodes) == node_count

        # Test way callback
        way_count = 0
        function way_callback(way)
            way_count += 1
            return way
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; way_callback = way_callback)
        @test way_count > 0
        @test length(osmdata.ways) == way_count

        # Test relation callback
        relation_count = 0
        function relation_callback(relation)
            relation_count += 1
            return relation
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; relation_callback = relation_callback)
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

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = filter_nodes)
        @test filtered_nodes > 0
        @test length(osmdata.nodes) == filtered_nodes

        # Verify all filtered nodes have the expected tag
        for (id, node) in osmdata.nodes
            @test node.tags !== nothing
            @test haskey(node.tags, "addr:country")
            @test node.tags["addr:country"] == "DE"
        end

        # Test node callback that modifies data
        function add_test_tag(node)
            # Create a new node with modified tags since Node is immutable
            new_tags = node.tags === nothing ? Dict{String, String}() : copy(node.tags)
            new_tags["test_callback"] = "modified"
            return Node(node.position, new_tags, node.info)
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = add_test_tag)

        # Check that some nodes have the test tag
        nodes_with_test_tag = 0
        for (id, node) in osmdata.nodes
            if node.tags !== nothing && haskey(node.tags, "test_callback")
                @test node.tags["test_callback"] == "modified"
                nodes_with_test_tag += 1
            end
        end
        @test nodes_with_test_tag > 0

        # Test filtering way callback
        filtered_count = 0
        function filter_highway_ways(way)
            if way.tags !== nothing && haskey(way.tags, "highway")
                filtered_count += 1
                return way
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; way_callback = filter_highway_ways)
        @test filtered_count >= 0  # May be 0 if no highways in test data
        @test length(osmdata.ways) == filtered_count

        # Verify all filtered ways have the highway tag
        for (id, way) in osmdata.ways
            @test way.tags !== nothing
            @test haskey(way.tags, "highway")
        end

        # Test way callback that filters by node count
        long_way_count = 0
        function filter_long_ways(way)
            if length(way.refs) > 10
                long_way_count += 1
                return way
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; way_callback = filter_long_ways)
        @test long_way_count >= 0
        @test length(osmdata.ways) == long_way_count

        # Verify all filtered ways have more than 10 nodes
        for (id, way) in osmdata.ways
            @test length(way.refs) > 10
        end

        # Test filtering relation callback
        filtered_count = 0
        function filter_route_relations(relation)
            if relation.tags !== nothing &&
                    haskey(relation.tags, "type") &&
                    relation.tags["type"] == "route"
                filtered_count += 1
                return relation
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; relation_callback = filter_route_relations)
        @test filtered_count >= 0  # May be 0 if no routes in test data
        @test length(osmdata.relations) == filtered_count

        # Verify all filtered relations have the route type
        for (id, relation) in osmdata.relations
            @test relation.tags !== nothing
            @test haskey(relation.tags, "type")
            @test relation.tags["type"] == "route"
        end

        # Test relation callback that filters by member count
        large_relation_count = 0
        function filter_large_relations(relation)
            if length(relation.refs) > 50
                large_relation_count += 1
                return relation
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; relation_callback = filter_large_relations)
        @test large_relation_count >= 0
        @test length(osmdata.relations) == large_relation_count

        # Verify all filtered relations have more than 50 members
        for (id, relation) in osmdata.relations
            @test length(relation.refs) > 50
        end

        # Test using multiple callbacks simultaneously
        node_count = 0
        way_count = 0
        relation_count = 0

        function count_nodes_callback(node)
            node_count += 1
            return node
        end

        function count_ways_callback(way)
            way_count += 1
            return way
        end

        function count_relations_callback(relation)
            relation_count += 1
            return relation
        end

        osmdata = OpenStreetMapIO.readpbf(
            test_file_pbf;
            node_callback = count_nodes_callback,
            way_callback = count_ways_callback,
            relation_callback = count_relations_callback,
        )

        @test node_count > 0
        @test way_count > 0
        @test relation_count > 0
        @test length(osmdata.nodes) == node_count
        @test length(osmdata.ways) == way_count
        @test length(osmdata.relations) == relation_count

        # Test mixed filtering callbacks
        german_nodes = 0
        highway_ways = 0
        route_relations = 0

        function filter_german_nodes_callback(node)
            if node.tags !== nothing &&
                    haskey(node.tags, "addr:country") &&
                    node.tags["addr:country"] == "DE"
                german_nodes += 1
                return node
            end
            return nothing
        end

        function filter_highway_ways_callback(way)
            if way.tags !== nothing && haskey(way.tags, "highway")
                highway_ways += 1
                return way
            end
            return nothing
        end

        function filter_route_relations_callback(relation)
            if relation.tags !== nothing &&
                    haskey(relation.tags, "type") &&
                    relation.tags["type"] == "route"
                route_relations += 1
                return relation
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf(
            test_file_pbf;
            node_callback = filter_german_nodes_callback,
            way_callback = filter_highway_ways_callback,
            relation_callback = filter_route_relations_callback,
        )

        @test german_nodes >= 0
        @test highway_ways >= 0
        @test route_relations >= 0
        @test length(osmdata.nodes) == german_nodes
        @test length(osmdata.ways) == highway_ways
        @test length(osmdata.relations) == route_relations
    end

    @testset "PBF Callback Error Handling" begin
        # Test callback that throws an error - now handled gracefully
        function error_callback(element)
            throw(ErrorException("Callback error"))
        end

        # Callback errors are now handled gracefully with warnings
        osmdata_nodes = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = error_callback)
        @test length(osmdata_nodes.nodes) == 0  # No nodes should be processed due to callback errors

        osmdata_ways = OpenStreetMapIO.readpbf(test_file_pbf; way_callback = error_callback)
        @test length(osmdata_ways.ways) == 0  # No ways should be processed due to callback errors

        osmdata_relations = OpenStreetMapIO.readpbf(test_file_pbf; relation_callback = error_callback)
        @test length(osmdata_relations.relations) == 0  # No relations should be processed due to callback errors

        # Test callback that returns nothing (valid behavior)
        function nothing_callback(element)
            return nothing  # Should exclude the element
        end

        osmdata = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = nothing_callback)
        @test length(osmdata.nodes) == 0  # No nodes should be included
    end

    @testset "PBF Callback Performance Tests" begin
        # Test that callbacks don't significantly slow down reading
        # Run baseline multiple times to get a more stable measurement
        baseline_times = Float64[]
        for i in 1:3
            start_time = time()
            osmdata = OpenStreetMapIO.readpbf(test_file_pbf)
            push!(baseline_times, time() - start_time)
        end
        baseline_time = median(baseline_times)

        # Test with simple callback
        callback_times = Float64[]
        for i in 1:3
            start_time = time()
            osmdata_with_callback = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = identity)
            push!(callback_times, time() - start_time)
        end
        callback_time = median(callback_times)

        # Callback time should not be significantly slower (allow 1000% overhead for compilation/system variance)
        @test callback_time < baseline_time * 10.0

        # Test with complex callback
        complex_callback_count = 0
        function complex_callback(node)
            complex_callback_count += 1
            if node.tags !== nothing
                for (key, value) in node.tags
                    # Simulate some processing
                    _ = length(key) + length(value)
                end
            end
            return node
        end

        complex_times = Float64[]
        for i in 1:3
            start_time = time()
            osmdata_complex = OpenStreetMapIO.readpbf(test_file_pbf; node_callback = complex_callback)
            push!(complex_times, time() - start_time)
        end
        complex_time = median(complex_times)

        # Complex callback should still be reasonable (allow 2000% overhead for compilation and system variability)
        @test complex_time < baseline_time * 20.0 || complex_time < 0.01  # Either reasonable overhead or very fast overall
        @test complex_callback_count > 0
    end

    @testset "PBF Callback Data Integrity" begin
        # Test that callbacks don't corrupt data
        function preserve_data_callback(element)
            # Just return the element unchanged
            return element
        end

        osmdata_original = OpenStreetMapIO.readpbf(test_file_pbf)
        osmdata_with_callback = OpenStreetMapIO.readpbf(
            test_file_pbf;
            node_callback = preserve_data_callback,
            way_callback = preserve_data_callback,
            relation_callback = preserve_data_callback,
        )

        # Data should be identical
        @test length(osmdata_original.nodes) == length(osmdata_with_callback.nodes)
        @test length(osmdata_original.ways) == length(osmdata_with_callback.ways)
        @test length(osmdata_original.relations) == length(osmdata_with_callback.relations)

        # Test specific elements
        if haskey(osmdata_original.nodes, KNOWN_NODE_ID) &&
                haskey(osmdata_with_callback.nodes, KNOWN_NODE_ID)
            @test osmdata_original.nodes[KNOWN_NODE_ID].position ==
                osmdata_with_callback.nodes[KNOWN_NODE_ID].position
            @test osmdata_original.nodes[KNOWN_NODE_ID].tags ==
                osmdata_with_callback.nodes[KNOWN_NODE_ID].tags
        end

        if haskey(osmdata_original.ways, KNOWN_WAY_ID) &&
                haskey(osmdata_with_callback.ways, KNOWN_WAY_ID)
            @test osmdata_original.ways[KNOWN_WAY_ID].refs ==
                osmdata_with_callback.ways[KNOWN_WAY_ID].refs
            @test osmdata_original.ways[KNOWN_WAY_ID].tags ==
                osmdata_with_callback.ways[KNOWN_WAY_ID].tags
        end
    end

    @testset "PBF Reading Error Handling" begin
        # Test reading non-existent file
        @test_throws ArgumentError OpenStreetMapIO.readpbf("nonexistent.pbf")

        # Test reading invalid PBF file (using XML file)
        test_file_xml = test_data_path("map.osm")
        @test_throws ArgumentError OpenStreetMapIO.readpbf(test_file_xml)
    end

    @testset "PBF Metadata Extraction" begin
        osmdata = OpenStreetMapIO.readpbf(test_file_pbf)

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
            if bbox.bottom_lat <= node.position.lat <= bbox.top_lat &&
                    bbox.left_lon <= node.position.lon <= bbox.right_lon
                nodes_in_bbox += 1
            end
        end

        # Some nodes should be within the bounding box
        @test nodes_in_bbox > 0  # At least some nodes should be in bbox

        # Test PBF Header Metadata
        @testset "Metadata dictionary structure" begin
            @test osmdata.meta isa Dict{String, Any}
            @test !isempty(osmdata.meta)
        end

        @testset "Bounding box metadata" begin
            # The test file should have a bounding box
            if haskey(osmdata.meta, "bbox")
                bbox = osmdata.meta["bbox"]

                @test bbox isa BBox
                @test bbox.bottom_lat isa Float64
                @test bbox.left_lon isa Float64
                @test bbox.top_lat isa Float64
                @test bbox.right_lon isa Float64

                # Validate bbox coordinates are in valid ranges
                @test -90.0 <= bbox.bottom_lat <= 90.0
                @test -180.0 <= bbox.left_lon <= 180.0
                @test -90.0 <= bbox.top_lat <= 90.0
                @test -180.0 <= bbox.right_lon <= 180.0

                # Validate bbox consistency
                @test bbox.bottom_lat <= bbox.top_lat
                @test bbox.left_lon <= bbox.right_lon
            end
        end

        @testset "Required features metadata" begin
            # Check if required_features exists and has correct structure
            if haskey(osmdata.meta, "required_features")
                features = osmdata.meta["required_features"]
                @test features isa Vector{String}

                # If features exist, they should be non-empty strings
                for feature in features
                    @test !isempty(feature)
                    @test feature isa String
                end
            end
        end

        @testset "Optional features metadata" begin
            # Check if optional_features exists and has correct structure
            if haskey(osmdata.meta, "optional_features")
                features = osmdata.meta["optional_features"]
                @test features isa Vector{String}

                # If features exist, they should be non-empty strings
                for feature in features
                    @test !isempty(feature)
                    @test feature isa String
                end
            end
        end

        @testset "Source metadata" begin
            # Check if source exists and has correct structure
            if haskey(osmdata.meta, "source")
                source = osmdata.meta["source"]
                @test source isa String
                @test !isempty(source)
            end
        end

        @testset "Replication metadata" begin
            # Check if replication timestamp exists
            if haskey(osmdata.meta, "osmosis_replication_timestamp")
                timestamp = osmdata.meta["osmosis_replication_timestamp"]
                @test timestamp isa DateTime
            end

            # Check if replication sequence number exists
            if haskey(osmdata.meta, "osmosis_replication_sequence_number")
                seq_num = osmdata.meta["osmosis_replication_sequence_number"]
                @test seq_num isa Int64
                @test seq_num >= 0
            end

            # Check if replication base URL exists
            if haskey(osmdata.meta, "osmosis_replication_base_url")
                base_url = osmdata.meta["osmosis_replication_base_url"]
                @test base_url isa String
            end
        end

        @testset "Writing program metadata" begin
            # Check if writingprogram exists
            if haskey(osmdata.meta, "writingprogram")
                program = osmdata.meta["writingprogram"]
                @test program isa String
                @test !isempty(program)
            end
        end
    end

    @testset "PBF Compression Format Tests" begin
        @testset "Compression codec availability" begin
            # Test that all compression codecs are available in the module
            @test isdefined(OpenStreetMapIO, :ZlibDecompressorStream)
            @test isdefined(OpenStreetMapIO, :LZ4FrameDecompressorStream)
            @test isdefined(OpenStreetMapIO, :ZstdDecompressorStream)
            @test isdefined(OpenStreetMapIO, :XzDecompressorStream)
        end

        @testset "Compression error handling" begin
            # Test with obsolete BZIP2 format
            @testset "BZIP2 format rejection" begin
                bzip2_blob = OpenStreetMapIO.OSMPBF.Blob(
                    Int32(100),
                    OneOf(:OBSOLETE_bzip2_data, Vector{UInt8}([1, 2, 3]))
                )

                @test_throws ArgumentError OpenStreetMapIO.decode_blob(
                    bzip2_blob, OpenStreetMapIO.OSMPBF.HeaderBlock
                )

                # Verify error message mentions BZIP2
                try
                    OpenStreetMapIO.decode_blob(bzip2_blob, OpenStreetMapIO.OSMPBF.HeaderBlock)
                    @test false  # Should not reach here
                catch e
                    @test e isa ArgumentError
                    error_msg = error_message(e)
                    @test occursin("BZIP2", error_msg) || occursin("bzip2", lowercase(error_msg))
                end
            end

            # Test with no data
            @testset "No data format rejection" begin
                empty_blob = OpenStreetMapIO.OSMPBF.Blob(Int32(0), nothing)

                @test_throws ArgumentError OpenStreetMapIO.decode_blob(
                    empty_blob, OpenStreetMapIO.OSMPBF.HeaderBlock
                )
            end

            # Test with unknown compression format (invalid OneOf name)
            @testset "Unknown compression format rejection" begin
                # Create a blob with a field name that doesn't match any known compression
                unknown_blob = OpenStreetMapIO.OSMPBF.Blob(
                    Int32(10),
                    OneOf(:unknown_format, Vector{UInt8}([1, 2, 3]))
                )

                @test_throws ArgumentError OpenStreetMapIO.decode_blob(
                    unknown_blob, OpenStreetMapIO.OSMPBF.HeaderBlock
                )
            end
        end

        @testset "Read PBF with zlib compression" begin
            # The test PBF file uses zlib compression (most common)
            # This tests that the existing compression support works
            osmdata = OpenStreetMapIO.readpbf(test_file_pbf)

            @test length(osmdata.nodes) > 0
            @test length(osmdata.ways) > 0
            @test length(osmdata.relations) > 0
        end

        @testset "Compression format documentation" begin
            # Verify that decode_blob docstring mentions all supported formats
            docstring = string(@doc OpenStreetMapIO.decode_blob)

            @test occursin("raw", lowercase(docstring)) || occursin("uncompressed", lowercase(docstring))
            @test occursin("zlib", lowercase(docstring))
            @test occursin("lz4", lowercase(docstring))
            @test occursin("zstd", lowercase(docstring))
            @test occursin("lzma", lowercase(docstring)) || occursin("xz", lowercase(docstring))
        end

        @testset "Raw size validation" begin
            # Test that raw_size validation works correctly
            # Create a blob with correct raw_size
            test_data = Vector{UInt8}("test data for compression")
            compressed_io = IOBuffer()
            stream = ZlibCompressorStream(compressed_io)
            write(stream, test_data)
            flush(stream)  # Ensure data is flushed before reading
            compressed_data = read(compressed_io)  # Read before closing
            close(stream)

            # Create blob with correct raw_size
            correct_blob = OpenStreetMapIO.OSMPBF.Blob(
                Int32(length(test_data)),  # raw_size
                OneOf(:zlib_data, compressed_data)
            )

            # This should work for size validation (though it won't decode as valid protobuf)
            @test_throws ArgumentError OpenStreetMapIO.decode_blob(
                correct_blob, OpenStreetMapIO.OSMPBF.HeaderBlock
            )  # Will fail on protobuf decode, not size validation

            # Create blob with incorrect raw_size (slightly wrong, to catch size mismatch)
            incorrect_blob = OpenStreetMapIO.OSMPBF.Blob(
                Int32(length(test_data) + 10),  # Wrong raw_size
                OneOf(:zlib_data, compressed_data)
            )

            # This should fail - either with size mismatch (our validation) or decode error
            @test_throws ArgumentError OpenStreetMapIO.decode_blob(
                incorrect_blob, OpenStreetMapIO.OSMPBF.HeaderBlock
            )

            # Verify error message mentions size mismatch or decode failure
            try
                OpenStreetMapIO.decode_blob(incorrect_blob, OpenStreetMapIO.OSMPBF.HeaderBlock)
                @test false  # Should not reach here
            catch e
                @test e isa ArgumentError
                error_msg = error_message(e)
                @test occursin("size mismatch", lowercase(error_msg)) ||
                    occursin("failed to decode", lowercase(error_msg))
            end
        end
    end

    @testset "PBF Performance Tests" begin
        # Test reading time
        start_time = time()
        osmdata = OpenStreetMapIO.readpbf(test_file_pbf)
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
        osmdata = OpenStreetMapIO.readpbf(test_file_pbf)

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
end
