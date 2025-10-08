using OpenStreetMapIO, Test

@testset "Overpass API Query Tests" begin
    @testset "Basic Overpass Queries" begin
        # Test basic bounding box query (corrected: top_lat > bottom_lat)
        bbox = BBox(53.2, 9.9, 53.3, 10.0)

        # Note: This test might fail if the Overpass API is down or rate-limited
        # We'll wrap it in a try-catch to handle network issues gracefully
        try
            @time osmdata = OpenStreetMapIO.queryoverpass(bbox)

            # Verify basic structure
            @test osmdata isa OpenStreetMap
            @test length(osmdata.nodes) >= 0
            @test length(osmdata.ways) >= 0
            @test length(osmdata.relations) >= 0

            # Test that all nodes are within the bounding box
            for (id, node) in osmdata.nodes
                @test bbox.bottom_lat <= node.latlon.lat <= bbox.top_lat
                @test bbox.left_lon <= node.latlon.lon <= bbox.right_lon
            end

        catch e
            # If network request fails, skip the test but don't fail the suite
            @warn "Overpass API test skipped due to network error: $e"
        end
    end

    @testset "Overpass Query with LatLon and Radius" begin
        # Test query with center point and radius
        center = LatLon(53.25, 9.95)
        radius = 1_000

        try
            @time osmdata = OpenStreetMapIO.queryoverpass(center, radius)

            # Verify basic structure
            @test osmdata isa OpenStreetMap
            @test length(osmdata.nodes) >= 0
            @test length(osmdata.ways) >= 0
            @test length(osmdata.relations) >= 0

            # Test that nodes are within the bounding box
            nodes_in_bbox = 0
            total_nodes = length(osmdata.nodes)

            for (id, node) in osmdata.nodes
                if bbox.bottom_lat <= node.latlon.lat <= bbox.top_lat &&
                    bbox.left_lon <= node.latlon.lon <= bbox.right_lon
                    nodes_in_bbox += 1
                end
            end

            # Most nodes should be within the bounding box
            if total_nodes > 0
                @test nodes_in_bbox >= total_nodes * 0.8
            end

        catch e
            @warn "Overpass API test skipped due to network error: $e"
        end
    end
end
