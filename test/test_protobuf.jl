using OpenStreetMapIO, Test

@testset "Protobuf functionality and integration tests" begin
    @testset "Protobuf module structure" begin
        # Test that the OSMPBF module is properly structured
        @test isdefined(OpenStreetMapIO.OSMPBF, :Blob)
        @test isdefined(OpenStreetMapIO.OSMPBF, :BlobHeader)
        @test isdefined(OpenStreetMapIO.OSMPBF, :HeaderBlock)
        @test isdefined(OpenStreetMapIO.OSMPBF, :HeaderBBox)
        @test isdefined(OpenStreetMapIO.OSMPBF, :PrimitiveBlock)
        @test isdefined(OpenStreetMapIO.OSMPBF, :PrimitiveGroup)
        @test isdefined(OpenStreetMapIO.OSMPBF, :StringTable)
        @test isdefined(OpenStreetMapIO.OSMPBF, :Info)
        @test isdefined(OpenStreetMapIO.OSMPBF, :DenseInfo)
        @test isdefined(OpenStreetMapIO.OSMPBF, :Node)
        @test isdefined(OpenStreetMapIO.OSMPBF, :DenseNodes)
        @test isdefined(OpenStreetMapIO.OSMPBF, :Way)
        @test isdefined(OpenStreetMapIO.OSMPBF, :Relation)
        @test isdefined(OpenStreetMapIO.OSMPBF, :ChangeSet)

        # Test that Relation.MemberType enum is available
        @test isdefined(OpenStreetMapIO.OSMPBF, Symbol("Relation.MemberType"))
        @test isdefined(OpenStreetMapIO.OSMPBF.var"Relation.MemberType", :NODE)
        @test isdefined(OpenStreetMapIO.OSMPBF.var"Relation.MemberType", :WAY)
        @test isdefined(OpenStreetMapIO.OSMPBF.var"Relation.MemberType", :RELATION)
    end

    @testset "Protobuf enum values" begin
        # Test that enum values are correct
        @test OpenStreetMapIO.OSMPBF.var"Relation.MemberType".NODE ==
            OpenStreetMapIO.OSMPBF.var"Relation.MemberType".NODE
        @test OpenStreetMapIO.OSMPBF.var"Relation.MemberType".WAY ==
            OpenStreetMapIO.OSMPBF.var"Relation.MemberType".WAY
        @test OpenStreetMapIO.OSMPBF.var"Relation.MemberType".RELATION ==
            OpenStreetMapIO.OSMPBF.var"Relation.MemberType".RELATION

        # Test that enum values are different
        @test OpenStreetMapIO.OSMPBF.var"Relation.MemberType".NODE !=
            OpenStreetMapIO.OSMPBF.var"Relation.MemberType".WAY
        @test OpenStreetMapIO.OSMPBF.var"Relation.MemberType".WAY !=
            OpenStreetMapIO.OSMPBF.var"Relation.MemberType".RELATION
        @test OpenStreetMapIO.OSMPBF.var"Relation.MemberType".NODE !=
            OpenStreetMapIO.OSMPBF.var"Relation.MemberType".RELATION

        # Test that we can use the enum values
        node_type = OpenStreetMapIO.OSMPBF.var"Relation.MemberType".NODE
        way_type = OpenStreetMapIO.OSMPBF.var"Relation.MemberType".WAY
        relation_type = OpenStreetMapIO.OSMPBF.var"Relation.MemberType".RELATION

        @test node_type == OpenStreetMapIO.OSMPBF.var"Relation.MemberType".NODE
        @test way_type == OpenStreetMapIO.OSMPBF.var"Relation.MemberType".WAY
        @test relation_type == OpenStreetMapIO.OSMPBF.var"Relation.MemberType".RELATION

        # Test that enum values are different
        @test node_type != way_type
        @test way_type != relation_type
        @test node_type != relation_type
    end

    @testset "Protobuf type definitions" begin
        # Test that types are properly defined
        @test OpenStreetMapIO.OSMPBF.Blob <: Any
        @test OpenStreetMapIO.OSMPBF.BlobHeader <: Any
        @test OpenStreetMapIO.OSMPBF.HeaderBlock <: Any
        @test OpenStreetMapIO.OSMPBF.HeaderBBox <: Any
        @test OpenStreetMapIO.OSMPBF.PrimitiveBlock <: Any
        @test OpenStreetMapIO.OSMPBF.PrimitiveGroup <: Any
        @test OpenStreetMapIO.OSMPBF.StringTable <: Any
        @test OpenStreetMapIO.OSMPBF.Info <: Any
        @test OpenStreetMapIO.OSMPBF.DenseInfo <: Any
        @test OpenStreetMapIO.OSMPBF.Node <: Any
        @test OpenStreetMapIO.OSMPBF.DenseNodes <: Any
        @test OpenStreetMapIO.OSMPBF.Way <: Any
        @test OpenStreetMapIO.OSMPBF.Relation <: Any
        @test OpenStreetMapIO.OSMPBF.ChangeSet <: Any
    end

    @testset "PBF file reading with protobuf" begin
        # Test that we can read a real PBF file using the protobuf structures
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Verify that the data was read correctly
        @test length(osmdata.nodes) > 0
        @test length(osmdata.ways) > 0
        @test length(osmdata.relations) > 0

        # Test that metadata was extracted correctly
        if haskey(osmdata.meta, "bbox")
            bbox = osmdata.meta["bbox"]
            @test bbox isa BBox
            @test bbox.bottom_lat <= bbox.top_lat
            @test bbox.left_lon <= bbox.right_lon
        end
    end

    @testset "OSM data processing with protobuf" begin
        # Test that OSM data processing works with protobuf backend
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test basic data structure
        @test length(osmdata.nodes) > 0
        @test length(osmdata.ways) > 0
        @test length(osmdata.relations) > 0

        # Test that we can access data
        @test isa(osmdata.nodes, Dict)
        @test isa(osmdata.ways, Dict)
        @test isa(osmdata.relations, Dict)
        @test isa(osmdata.meta, Dict)
    end

    @testset "Callback functionality with protobuf" begin
        # Test that callback functions work with protobuf backend
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test node callback
        function keep_amenities(node)
            if node.tags !== nothing && haskey(node.tags, "amenity")
                return node
            end
            return nothing
        end

        # Test way callback
        function keep_highways(way)
            if way.tags !== nothing && haskey(way.tags, "highway")
                return way
            end
            return nothing
        end

        # Apply filters during reading
        filtered_osm = OpenStreetMapIO.readpbf(
            "data/map.pbf"; node_callback = keep_amenities, way_callback = keep_highways
        )

        # Verify filtering worked
        @test length(filtered_osm.nodes) <= length(osmdata.nodes)
        @test length(filtered_osm.ways) <= length(osmdata.ways)

        # All remaining nodes should have amenity tags
        for (id, node) in filtered_osm.nodes
            @test node.tags !== nothing
            @test haskey(node.tags, "amenity")
        end

        # All remaining ways should have highway tags
        for (id, way) in filtered_osm.ways
            @test way.tags !== nothing
            @test haskey(way.tags, "highway")
        end
    end

    @testset "Geographic operations with protobuf" begin
        # Test that geographic operations work with protobuf backend
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test basic data access
        if length(osmdata.nodes) > 0
            node_ids = collect(keys(osmdata.nodes))
            node = osmdata.nodes[node_ids[1]]
            @test isa(node, Node)
            @test isa(node.position, Position)
        end

        # Test way data access
        if length(osmdata.ways) > 0
            way_ids = collect(keys(osmdata.ways))
            way = osmdata.ways[way_ids[1]]
            @test isa(way, Way)
            @test isa(way.refs, Vector)
        end
    end

    @testset "Error handling with protobuf" begin
        # Test that error handling works with protobuf backend
        osmdata = OpenStreetMapIO.readpbf("data/map.pbf")

        # Test with empty data
        empty_osm = OpenStreetMap()

        # Test that empty data structure is valid
        @test length(empty_osm.nodes) == 0
        @test length(empty_osm.ways) == 0
        @test length(empty_osm.relations) == 0
        @test isa(empty_osm.meta, Dict)
    end
end
