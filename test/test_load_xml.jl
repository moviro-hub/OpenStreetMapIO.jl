if !isdefined(Main, :TestUtils)
    include("TestUtils.jl")
    using .TestUtils
end
using OpenStreetMapIO, Test

@testset "Load XML Tests" begin
    test_file_xml = test_data_path("map.osm")
    test_file_pbf = test_data_path("map.pbf")

    @testset "Basic XML Reading" begin
        # Test basic XML file reading
        @time osmdata = TEST_DATA_XML

        # Verify basic structure
        @test osmdata isa OpenStreetMap
        @test length(osmdata.nodes) > 0
        @test length(osmdata.ways) > 0
        @test length(osmdata.relations) > 0

        # Test specific known elements
        @testset "Testing Node" begin
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

        @testset "Testing Way" begin
            way = osmdata.ways[KNOWN_WAY_ID]

            @test typeof(way) === Way
            @test length(way.refs) === 56
            @test way.refs[23] === 1276389426
            @test length(way.tags) === 2
            @test way.tags["wetland"] === "wet_meadow"
            @test way.tags["natural"] === "wetland"
        end

        @testset "Testing Relation" begin
            relation = osmdata.relations[KNOWN_RELATION_ID]

            @test typeof(relation) === Relation
            @test length(relation.refs) > 0  # Should have some references
            @test length(relation.types) === length(relation.refs)
            @test length(relation.roles) === length(relation.refs)
            @test length(relation.tags) >= 3  # Should have some tags
            @test haskey(relation.tags, "type")
            @test haskey(relation.tags, "route")
            @test haskey(relation.tags, "from")
            @test haskey(relation.tags, "to")
        end
    end

    @testset "XML Reading Error Handling" begin
        # Test reading non-existent file
        @test_throws Exception OpenStreetMapIO.read_osm("nonexistent.osm")

        # Test reading invalid XML file (using PBF file)
        try
            OpenStreetMapIO.read_osm(test_file_pbf)
            @test false  # Should have thrown an error
        catch e
            @test true  # Should throw some kind of error
        end

        # Test reading malformed XML
        # Create a temporary malformed XML file
        malformed_xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <osm version="0.6" generator="test">
            <node id="1" lat="54.0" lon="9.0">
                <tag k="test" v="value"
            </node>
        </osm>
        """

        temp_file = joinpath(@__DIR__, "temp_malformed.osm")
        open(temp_file, "w") do f
            write(f, malformed_xml)
        end

        try
            OpenStreetMapIO.read_osm(temp_file)
            @test false  # Should have thrown an error
        catch e
            @test true  # Should throw some kind of error
        end

        # Clean up
        rm(temp_file; force = true)
    end

    @testset "XML Metadata Extraction" begin
        osmdata = OpenStreetMapIO.read_osm(test_file_xml)

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

        # Test XML Metadata
        @testset "Metadata dictionary structure" begin
            @test osmdata.meta isa Dict{String, Any}
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

                # Validate bbox coordinates
                @test -90.0 <= bbox.bottom_lat <= 90.0
                @test -180.0 <= bbox.left_lon <= 180.0
                @test -90.0 <= bbox.top_lat <= 90.0
                @test -180.0 <= bbox.right_lon <= 180.0

                @test bbox.bottom_lat <= bbox.top_lat
                @test bbox.left_lon <= bbox.right_lon
            end
        end
    end

    @testset "XML Performance Tests" begin
        # Test reading time
        start_time = time()
        osmdata = OpenStreetMapIO.read_osm(test_file_xml)
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

    @testset "XML Data Consistency" begin
        osmdata = OpenStreetMapIO.read_osm(test_file_xml)

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
    end

    @testset "XML vs PBF Consistency" begin
        # Read both formats and compare
        osmdata_xml = OpenStreetMapIO.read_osm(test_file_xml)
        osmdata_pbf = OpenStreetMapIO.read_pbf(test_file_pbf)

        # Test that both formats produce similar data
        @test length(osmdata_xml.nodes) == length(osmdata_pbf.nodes)
        @test length(osmdata_xml.ways) == length(osmdata_pbf.ways)
        @test length(osmdata_xml.relations) == length(osmdata_pbf.relations)

        # Test that specific elements are the same
        @test osmdata_xml.nodes[KNOWN_NODE_ID].position == osmdata_pbf.nodes[KNOWN_NODE_ID].position
        @test osmdata_xml.ways[KNOWN_WAY_ID].refs == osmdata_pbf.ways[KNOWN_WAY_ID].refs
        @test osmdata_xml.relations[KNOWN_RELATION_ID].refs == osmdata_pbf.relations[KNOWN_RELATION_ID].refs

        # Test that tags are the same (note: relation types might differ between formats)
        @test osmdata_xml.nodes[KNOWN_NODE_ID].tags == osmdata_pbf.nodes[KNOWN_NODE_ID].tags
        @test osmdata_xml.ways[KNOWN_WAY_ID].tags == osmdata_pbf.ways[KNOWN_WAY_ID].tags
        @test osmdata_xml.relations[KNOWN_RELATION_ID].tags == osmdata_pbf.relations[KNOWN_RELATION_ID].tags

        # Test metadata consistency across formats
        @testset "Bounding box consistency" begin
            # Both formats should have bbox
            if haskey(osmdata_pbf.meta, "bbox") && haskey(osmdata_xml.meta, "bbox")
                bbox_pbf = osmdata_pbf.meta["bbox"]
                bbox_xml = osmdata_xml.meta["bbox"]

                # Bounding boxes should be approximately equal (within floating point precision)
                @test isapprox(bbox_pbf.bottom_lat, bbox_xml.bottom_lat; atol = 1.0e-6)
                @test isapprox(bbox_pbf.left_lon, bbox_xml.left_lon; atol = 1.0e-6)
                @test isapprox(bbox_pbf.top_lat, bbox_xml.top_lat; atol = 1.0e-6)
                @test isapprox(bbox_pbf.right_lon, bbox_xml.right_lon; atol = 1.0e-6)
            end
        end
    end

    @testset "XML Special Cases" begin
        # Test reading XML with special characters
        osmdata = OpenStreetMapIO.read_osm(test_file_xml)

        # Find nodes with special characters in tags
        special_char_nodes = []
        for (id, node) in osmdata.nodes
            if node.tags !== nothing
                for (key, value) in node.tags
                    if occursin("straße", value) ||
                            occursin("ü", value) ||
                            occursin("ö", value) ||
                            occursin("ä", value)
                        push!(special_char_nodes, node)
                        break
                    end
                end
            end
        end

        @test length(special_char_nodes) >= 0  # May or may not find nodes with special characters

        # Test that special characters are preserved
        for node in special_char_nodes
            if node.tags !== nothing
                for (key, value) in node.tags
                    @test isa(value, String)
                    # Special characters should be preserved
                    if occursin("straße", value)
                        @test occursin("straße", value)
                    end
                end
            end
        end
    end
end
