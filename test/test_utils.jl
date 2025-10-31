# Test utility functions and shared test data
# This module provides common utilities used across all test files
# Uses a guard to prevent redefinition when included multiple times

if !@isdefined(TEST_UTILS_LOADED)
    using OpenStreetMapIO, Test

    # Simple median function for performance tests
    function median(x::Vector{T}) where {T}
        sorted_x = sort(x)
        n = length(sorted_x)
        if n % 2 == 1
            return sorted_x[(n + 1) ÷ 2]
        else
            return (sorted_x[n ÷ 2] + sorted_x[n ÷ 2 + 1]) / 2
        end
    end

    # Shared test data - loaded once and reused
    const TEST_DATA_PBF = begin
        test_file = joinpath(@__DIR__, "data", "map.pbf")
        try
            OpenStreetMapIO.readpbf(test_file)
        catch
            OpenStreetMap()  # Empty data if file not available
        end
    end

    const TEST_DATA_XML = begin
        test_file = joinpath(@__DIR__, "data", "map.osm")
        try
            OpenStreetMapIO.readosm(test_file)
        catch
            OpenStreetMap()  # Empty data if file not available
        end
    end

    # Known test elements for consistent testing
    const KNOWN_NODE_ID = 1675598406
    const KNOWN_WAY_ID = 889648159
    const KNOWN_RELATION_ID = 12475101

    const TEST_POINT_1 = Position(54.2619665, 9.9854149)
    const TEST_POINT_2 = Position(54.262, 9.986)
    const TEST_BBOX = BBox(54.0, 9.0, 55.0, 10.0)

    # Helper function to check if test data is available
    function has_test_data()
        return length(TEST_DATA_PBF.nodes) > 0
    end

    # Helper function to create test OSM data
    function create_test_osm_data()
        nodes = Dict(1 => Node(Position(54.0, 9.0), Dict("test" => "node1"), nothing))
        ways = Dict(1 => Way([1], Dict("highway" => "primary"), nothing, nothing))
        relations = Dict(1 => Relation([1], ["node"], ["role"], Dict("type" => "route"), nothing))
        meta = Dict{String, Any}("bbox" => BBox(54.0, 9.0, 55.0, 10.0))
        return OpenStreetMap(nodes, ways, relations, meta)
    end

    # Helper function for performance timing
    function time_function(f, iterations = 1000)
        times = Float64[]
        for _ in 1:3  # Run 3 times and take median
            start_time = time()
            for _ in 1:iterations
                f()
            end
            push!(times, time() - start_time)
        end
        return median(times)
    end

    # Helper function to get test data file path
    function test_data_path(filename)
        return joinpath(@__DIR__, "data", filename)
    end

    const TEST_UTILS_LOADED = true
end
