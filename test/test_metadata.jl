using OpenStreetMapIO, Test

@testset "Metadata Extraction Tests" begin
    @testset "PBF Header Metadata" begin
        # Read test PBF file
        test_file = joinpath(@__DIR__, "data", "map.pbf")
        osmdata = OpenStreetMapIO.readpbf(test_file)

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

    @testset "XML Metadata" begin
        # Read test XML file
        test_file = joinpath(@__DIR__, "data", "map.osm")
        osmdata = OpenStreetMapIO.readosm(test_file)

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

    @testset "Metadata consistency across formats" begin
        # Read both PBF and XML versions
        pbf_file = joinpath(@__DIR__, "data", "map.pbf")
        xml_file = joinpath(@__DIR__, "data", "map.osm")

        osmdata_pbf = OpenStreetMapIO.readpbf(pbf_file)
        osmdata_xml = OpenStreetMapIO.readosm(xml_file)

        @testset "Bounding box consistency" begin
            # Both formats should have bbox
            if haskey(osmdata_pbf.meta, "bbox") && haskey(osmdata_xml.meta, "bbox")
                bbox_pbf = osmdata_pbf.meta["bbox"]
                bbox_xml = osmdata_xml.meta["bbox"]

                # Bounding boxes should be approximately equal (within floating point precision)
                @test isapprox(bbox_pbf.bottom_lat, bbox_xml.bottom_lat; atol=1e-6)
                @test isapprox(bbox_pbf.left_lon, bbox_xml.left_lon; atol=1e-6)
                @test isapprox(bbox_pbf.top_lat, bbox_xml.top_lat; atol=1e-6)
                @test isapprox(bbox_pbf.right_lon, bbox_xml.right_lon; atol=1e-6)
            end
        end
    end

    @testset "Empty metadata handling" begin
        # Create empty OSM data
        empty_osm = OpenStreetMap()

        @test empty_osm.meta isa Dict{String, Any}
        @test isempty(empty_osm.meta)
    end
end
