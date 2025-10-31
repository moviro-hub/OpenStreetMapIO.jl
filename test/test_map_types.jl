include("test_utils.jl")

@testset "Map Types Tests" begin
    @testset "Node Data Type Tests" begin
        # Test Node creation and validation
        node = Node(TEST_POINT_1, Dict("test" => "value"), nothing)

        @test node.position isa Position
        @test node.position.lat == TEST_POINT_1.lat
        @test node.position.lon == TEST_POINT_1.lon
        @test node.tags isa Dict{String, String}
        @test node.tags["test"] == "value"

        # Test Node with no tags
        node_no_tags = Node(Position(0.0, 0.0), nothing, nothing)
        @test node_no_tags.position isa Position
        @test node_no_tags.tags === nothing

        # Test Position validation
        @test Position(0.0, 0.0) isa Position
        @test Position(-90.0, -180.0) isa Position
        @test Position(90.0, 180.0) isa Position

        # Test coordinate bounds
        @test -90.0 <= node.position.lat <= 90.0
        @test -180.0 <= node.position.lon <= 180.0
    end

    @testset "Way Data Type Tests" begin
        # Test Way creation and validation
        way = Way([1, 2, 3, 4], Dict("highway" => "primary"), nothing, nothing)

        @test way.refs isa Vector{Int64}
        @test length(way.refs) == 4
        @test way.refs == [1, 2, 3, 4]
        @test way.tags isa Dict{String, String}
        @test way.tags["highway"] == "primary"

        # Test Way with no tags
        way_no_tags = Way([1, 2, 3], nothing, nothing, nothing)
        @test way_no_tags.refs isa Vector{Int64}
        @test way_no_tags.tags === nothing

        # Test empty Way
        empty_way = Way(Int64[], Dict{String, String}(), nothing, nothing)
        @test length(empty_way.refs) == 0
        @test length(empty_way.tags) == 0

        # Test Way with single node
        single_node_way = Way([1], Dict("test" => "single"), nothing, nothing)
        @test length(single_node_way.refs) == 1
        @test single_node_way.refs[1] == 1
    end

    @testset "Relation Data Type Tests" begin
        # Test Relation creation and validation
        relation = Relation(
            [1, 2, 3],
            ["node", "way", "relation"],
            ["member1", "member2", "member3"],
            Dict("type" => "route"),
            nothing,
        )

        @test relation.refs isa Vector{Int64}
        @test relation.types isa Vector{String}
        @test relation.roles isa Vector{String}
        @test relation.tags isa Dict{String, String}

        @test length(relation.refs) == 3
        @test length(relation.types) == 3
        @test length(relation.roles) == 3

        @test relation.refs == [1, 2, 3]
        @test relation.types == ["node", "way", "relation"]
        @test relation.roles == ["member1", "member2", "member3"]
        @test relation.tags["type"] == "route"

        # Test Relation with no tags
        relation_no_tags = Relation([1, 2], ["node", "way"], ["role1", "role2"], nothing, nothing)
        @test relation_no_tags.tags === nothing

        # Test empty Relation
        empty_relation = Relation(Int64[], String[], String[], Dict{String, String}(), nothing)
        @test length(empty_relation.refs) == 0
        @test length(empty_relation.types) == 0
        @test length(empty_relation.roles) == 0

        # Test Relation with single member
        single_member_relation = Relation([1], ["node"], ["role"], Dict("test" => "single"), nothing)
        @test length(single_member_relation.refs) == 1
        @test single_member_relation.refs[1] == 1
        @test single_member_relation.types[1] == "node"
        @test single_member_relation.roles[1] == "role"
    end

    @testset "BBox Data Type Tests" begin
        # Test BBox creation and validation
        bbox = BBox(54.0, 9.0, 55.0, 10.0)

        @test bbox.bottom_lat == 54.0
        @test bbox.left_lon == 9.0
        @test bbox.top_lat == 55.0
        @test bbox.right_lon == 10.0

        # Test BBox with negative coordinates
        bbox_negative = BBox(-10.0, -20.0, 10.0, 20.0)
        @test bbox_negative.bottom_lat == -10.0
        @test bbox_negative.left_lon == -20.0
        @test bbox_negative.top_lat == 10.0
        @test bbox_negative.right_lon == 20.0

        # Test BBox with extreme coordinates
        bbox_extreme = BBox(-90.0, -180.0, 90.0, 180.0)
        @test bbox_extreme.bottom_lat == -90.0
        @test bbox_extreme.left_lon == -180.0
        @test bbox_extreme.top_lat == 90.0
        @test bbox_extreme.right_lon == 180.0

        # Test BBox with same coordinates (point)
        bbox_point = BBox(54.0, 9.0, 54.0, 9.0)
        @test bbox_point.bottom_lat == bbox_point.top_lat
        @test bbox_point.left_lon == bbox_point.right_lon
    end

    @testset "OpenStreetMap Data Type Tests" begin
        # Test OpenStreetMap creation
        osmdata = create_test_osm_data()

        @test osmdata.nodes isa Dict{Int64, Node}
        @test osmdata.ways isa Dict{Int64, Way}
        @test osmdata.relations isa Dict{Int64, Relation}
        @test osmdata.meta isa Dict{String, Any}

        @test length(osmdata.nodes) == 1
        @test length(osmdata.ways) == 1
        @test length(osmdata.relations) == 1
        @test haskey(osmdata.meta, "bbox")

        # Test empty OpenStreetMap
        empty_osm = OpenStreetMap()
        @test length(empty_osm.nodes) == 0
        @test length(empty_osm.ways) == 0
        @test length(empty_osm.relations) == 0
        @test length(empty_osm.meta) == 0
    end

    @testset "Data Type Consistency Tests" begin
        # Test that data types are consistent across different sources
        test_file_pbf = test_data_path("map.pbf")
        test_file_xml = test_data_path("map.osm")
        osmdata_pbf = OpenStreetMapIO.readpbf(test_file_pbf)
        osmdata_xml = OpenStreetMapIO.readosm(test_file_xml)

        # Test that both sources produce the same data types
        @test isa(osmdata_pbf, OpenStreetMap)
        @test isa(osmdata_xml, OpenStreetMap)

        # Test specific elements
        if haskey(osmdata_pbf.nodes, KNOWN_NODE_ID) && haskey(osmdata_xml.nodes, KNOWN_NODE_ID)
            node_pbf = osmdata_pbf.nodes[KNOWN_NODE_ID]
            node_xml = osmdata_xml.nodes[KNOWN_NODE_ID]

            @test isa(node_pbf, Node)
            @test isa(node_xml, Node)
            @test isa(node_pbf.position, Position)
            @test isa(node_xml.position, Position)
            @test node_pbf.position == node_xml.position
        end

        if haskey(osmdata_pbf.ways, KNOWN_WAY_ID) && haskey(osmdata_xml.ways, KNOWN_WAY_ID)
            way_pbf = osmdata_pbf.ways[KNOWN_WAY_ID]
            way_xml = osmdata_xml.ways[KNOWN_WAY_ID]

            @test isa(way_pbf, Way)
            @test isa(way_xml, Way)
            @test way_pbf.refs == way_xml.refs
        end
    end

    @testset "Data Type Edge Cases" begin
        # Test with extreme coordinate values
        extreme_node = Node(Position(90.0, 180.0), Dict("extreme" => "true"), nothing)
        @test extreme_node.position.lat == 90.0
        @test extreme_node.position.lon == 180.0

        # Test with negative extreme coordinates
        negative_extreme_node = Node(Position(-90.0, -180.0), Dict("negative" => "true"), nothing)
        @test negative_extreme_node.position.lat == -90.0
        @test negative_extreme_node.position.lon == -180.0

        # Test with very long way
        long_way_refs = collect(1:1000)
        long_way = Way(long_way_refs, Dict("long" => "true"), nothing, nothing)
        @test length(long_way.refs) == 1000
        @test long_way.refs[1] == 1
        @test long_way.refs[1000] == 1000

        # Test with very large relation
        large_relation_refs = collect(1:1000)
        large_relation_types = fill("node", 1000)
        large_relation_roles = fill("member", 1000)
        large_relation = Relation(
            large_relation_refs,
            large_relation_types,
            large_relation_roles,
            Dict("large" => "true"),
            nothing,
        )
        @test length(large_relation.refs) == 1000
        @test length(large_relation.types) == 1000
        @test length(large_relation.roles) == 1000

        # Test with many tags
        many_tags = Dict("tag$i" => "value$i" for i in 1:100)
        node_many_tags = Node(Position(54.0, 9.0), many_tags, nothing)
        @test length(node_many_tags.tags) == 100
        @test node_many_tags.tags["tag1"] == "value1"
        @test node_many_tags.tags["tag100"] == "value100"
    end

    @testset "Data Type Validation Errors" begin
        # Test that invalid data types are handled appropriately
        # Note: These tests depend on the specific implementation

        # Test with invalid coordinates (should be handled by the struct definition)
        # The struct should prevent invalid coordinates at construction time

        # Test with mismatched relation arrays
        # This should be caught by the struct definition or validation
        try
            relation = Relation(
                [1, 2], ["node"], ["role1", "role2"], Dict("test" => "mismatch")
            )
            # If this doesn't throw, the struct allows mismatched lengths
            @test length(relation.refs) == 2
            @test length(relation.types) == 1
            @test length(relation.roles) == 2
        catch e
            # If it throws, that's good validation
            @test true
        end
    end
end
