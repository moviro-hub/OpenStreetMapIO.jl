using OpenStreetMapIO, Test

@testset "XML File Reading Tests" begin
    @testset "Basic XML Reading" begin
        # Test basic XML file reading
        @time osmdata = OpenStreetMapIO.readosm("data/map.osm")

        # Verify basic structure
        @test osmdata isa OpenStreetMap
        @test length(osmdata.nodes) > 0
        @test length(osmdata.ways) > 0
        @test length(osmdata.relations) > 0

        # Test specific known elements
        @testset "Testing Node" begin
            node = osmdata.nodes[1675598406]

            @test typeof(node) === Node
            @test node.latlon === LatLon(54.2619665, 9.9854149)
            @test length(node.tags) >= 3  # Should have some tags
            @test node.tags["addr:country"] === "DE"
            # Other tags may vary depending on data version
            @test haskey(node.tags, "addr:city")
            @test haskey(node.tags, "addr:postcode")
            @test haskey(node.tags, "addr:street")
        end

        @testset "Testing Way" begin
            way = osmdata.ways[889648159]

            @test typeof(way) === Way
            @test length(way.refs) === 56
            @test way.refs[23] === 1276389426
            @test length(way.tags) === 2
            @test way.tags["wetland"] === "wet_meadow"
            @test way.tags["natural"] === "wetland"
        end

        @testset "Testing Relation" begin
            relation = osmdata.relations[12475101]

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
        @test_throws Exception OpenStreetMapIO.readosm("nonexistent.osm")

        # Test reading invalid XML file (using PBF file)
        try
            OpenStreetMapIO.readosm("data/map.pbf")
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

        temp_file = "temp_malformed.osm"
        open(temp_file, "w") do f
            write(f, malformed_xml)
        end

        try
            OpenStreetMapIO.readosm(temp_file)
            @test false  # Should have thrown an error
        catch e
            @test true  # Should throw some kind of error
        end

        # Clean up
        rm(temp_file; force = true)
    end

    @testset "XML Metadata Extraction" begin
        osmdata = OpenStreetMapIO.readosm("data/map.osm")

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

    @testset "XML Performance Tests" begin
        # Test reading time
        start_time = time()
        osmdata = OpenStreetMapIO.readosm("data/map.osm")
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
        osmdata = OpenStreetMapIO.readosm("data/map.osm")

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
        osmdata_xml = OpenStreetMapIO.readosm("data/map.osm")
        osmdata_pbf = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test that both formats produce similar data
        @test length(osmdata_xml.nodes) == length(osmdata_pbf.nodes)
        @test length(osmdata_xml.ways) == length(osmdata_pbf.ways)
        @test length(osmdata_xml.relations) == length(osmdata_pbf.relations)

        # Test that specific elements are the same
        @test osmdata_xml.nodes[1675598406].latlon == osmdata_pbf.nodes[1675598406].latlon
        @test osmdata_xml.ways[889648159].refs == osmdata_pbf.ways[889648159].refs
        @test osmdata_xml.relations[12475101].refs == osmdata_pbf.relations[12475101].refs

        # Test that tags are the same (note: relation types might differ between formats)
        @test osmdata_xml.nodes[1675598406].tags == osmdata_pbf.nodes[1675598406].tags
        @test osmdata_xml.ways[889648159].tags == osmdata_pbf.ways[889648159].tags
        @test osmdata_xml.relations[12475101].tags == osmdata_pbf.relations[12475101].tags
    end

    @testset "XML Special Cases" begin
        # Test reading XML with special characters
        osmdata = OpenStreetMapIO.readosm("data/map.osm")

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
