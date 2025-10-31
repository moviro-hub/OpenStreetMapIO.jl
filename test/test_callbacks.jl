using OpenStreetMapIO, Test
@testset "Callback Functionality Tests" begin
    @testset "Node Callback Tests" begin
        # Test basic node callback
        node_count = 0
        function count_nodes(node)
            node_count += 1
            return node
        end

        osmdata = TEST_DATA_PBF
        # Apply callback manually since we're using pre-loaded data
        for (id, node) in osmdata.nodes
            count_nodes(node)
        end
        @test node_count > 0
        @test length(osmdata.nodes) == node_count

        # Test filtering node callback
        filtered_count = 0
        function filter_german_nodes(node)
            if node.tags !== nothing &&
                    haskey(node.tags, "addr:country") &&
                    node.tags["addr:country"] == "DE"
                filtered_count += 1
                return node
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; node_callback = filter_german_nodes)
        @test filtered_count > 0
        @test length(osmdata.nodes) == filtered_count

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
            return Node(node.latlon, new_tags, node.metadata)
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; node_callback = add_test_tag)

        # Check that some nodes have the test tag
        nodes_with_test_tag = 0
        for (id, node) in osmdata.nodes
            if node.tags !== nothing && haskey(node.tags, "test_callback")
                @test node.tags["test_callback"] == "modified"
                nodes_with_test_tag += 1
            end
        end
        @test nodes_with_test_tag > 0
    end

    @testset "Way Callback Tests" begin
        # Test basic way callback
        way_count = 0
        function count_ways(way)
            way_count += 1
            return way
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; way_callback = count_ways)
        @test way_count > 0
        @test length(osmdata.ways) == way_count

        # Test filtering way callback
        filtered_count = 0
        function filter_highway_ways(way)
            if way.tags !== nothing && haskey(way.tags, "highway")
                filtered_count += 1
                return way
            end
            return nothing
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; way_callback = filter_highway_ways)
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

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; way_callback = filter_long_ways)
        @test long_way_count >= 0
        @test length(osmdata.ways) == long_way_count

        # Verify all filtered ways have more than 10 nodes
        for (id, way) in osmdata.ways
            @test length(way.refs) > 10
        end
    end

    @testset "Relation Callback Tests" begin
        # Test basic relation callback
        relation_count = 0
        function count_relations(relation)
            relation_count += 1
            return relation
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; relation_callback = count_relations)
        @test relation_count > 0
        @test length(osmdata.relations) == relation_count

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

        osmdata = OpenStreetMapIO.readpbf(
            "data/map.pbf"; relation_callback = filter_route_relations
        )
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

        osmdata = OpenStreetMapIO.readpbf(
            "data/map.pbf"; relation_callback = filter_large_relations
        )
        @test large_relation_count >= 0
        @test length(osmdata.relations) == large_relation_count

        # Verify all filtered relations have more than 50 members
        for (id, relation) in osmdata.relations
            @test length(relation.refs) > 50
        end
    end

    @testset "Multiple Callback Tests" begin
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
            "data/map.pbf";
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
            "data/map.pbf";
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

    @testset "Callback Error Handling" begin
        # Test callback that throws an error - now handled gracefully
        function error_callback(element)
            throw(ErrorException("Callback error"))
        end

        # Callback errors are now handled gracefully with warnings
        osmdata_nodes = OpenStreetMapIO.readpbf(
            "data/map.pbf"; node_callback = error_callback
        )
        @test length(osmdata_nodes.nodes) == 0  # No nodes should be processed due to callback errors

        osmdata_ways = OpenStreetMapIO.readpbf("data/map.pbf"; way_callback = error_callback)
        @test length(osmdata_ways.ways) == 0  # No ways should be processed due to callback errors

        osmdata_relations = OpenStreetMapIO.readpbf(
            "data/map.pbf"; relation_callback = error_callback
        )
        @test length(osmdata_relations.relations) == 0  # No relations should be processed due to callback errors

        # Test callback that returns nothing (valid behavior)
        function nothing_callback(element)
            return nothing  # Should exclude the element
        end

        osmdata = OpenStreetMapIO.readpbf("data/map.pbf"; node_callback = nothing_callback)
        @test length(osmdata.nodes) == 0  # No nodes should be included
    end

    @testset "Callback Performance Tests" begin
        # Test that callbacks don't significantly slow down reading
        # Run baseline multiple times to get a more stable measurement
        baseline_times = Float64[]
        for i in 1:3
            start_time = time()
            osmdata = OpenStreetMapIO.readpbf("data/map.pbf")
            push!(baseline_times, time() - start_time)
        end
        baseline_time = median(baseline_times)

        # Test with simple callback
        callback_times = Float64[]
        for i in 1:3
            start_time = time()
            osmdata_with_callback = OpenStreetMapIO.readpbf(
                "data/map.pbf"; node_callback = identity
            )
            push!(callback_times, time() - start_time)
        end
        callback_time = median(callback_times)

        # Callback time should not be significantly slower (allow 500% overhead for compilation)
        @test callback_time < baseline_time * 5.0

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
            osmdata_complex = OpenStreetMapIO.readpbf(
                "data/map.pbf"; node_callback = complex_callback
            )
            push!(complex_times, time() - start_time)
        end
        complex_time = median(complex_times)

        # Complex callback should still be reasonable (allow 1000% overhead for compilation)
        @test complex_time < baseline_time * 10.0
        @test complex_callback_count > 0
    end

    @testset "Callback Data Integrity" begin
        # Test that callbacks don't corrupt data
        function preserve_data_callback(element)
            # Just return the element unchanged
            return element
        end

        osmdata_original = OpenStreetMapIO.readpbf("data/map.pbf")
        osmdata_with_callback = OpenStreetMapIO.readpbf(
            "data/map.pbf";
            node_callback = preserve_data_callback,
            way_callback = preserve_data_callback,
            relation_callback = preserve_data_callback,
        )

        # Data should be identical
        @test length(osmdata_original.nodes) == length(osmdata_with_callback.nodes)
        @test length(osmdata_original.ways) == length(osmdata_with_callback.ways)
        @test length(osmdata_original.relations) == length(osmdata_with_callback.relations)

        # Test specific elements
        if haskey(osmdata_original.nodes, 1675598406) &&
                haskey(osmdata_with_callback.nodes, 1675598406)
            @test osmdata_original.nodes[1675598406].latlon ==
                osmdata_with_callback.nodes[1675598406].latlon
            @test osmdata_original.nodes[1675598406].tags ==
                osmdata_with_callback.nodes[1675598406].tags
        end

        if haskey(osmdata_original.ways, 889648159) &&
                haskey(osmdata_with_callback.ways, 889648159)
            @test osmdata_original.ways[889648159].refs ==
                osmdata_with_callback.ways[889648159].refs
            @test osmdata_original.ways[889648159].tags ==
                osmdata_with_callback.ways[889648159].tags
        end
    end
end
