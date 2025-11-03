using Test
using OpenStreetMapIO

@testset "validate_decompressed_size" begin
    data = Vector{UInt8}(undef, 10)
    fill!(data, 0x00)

    # Matching size: no error
    @test OpenStreetMapIO.validate_decompressed_size(data, Int32(10), "Test") === nothing

    # Nothing expected: no error
    @test OpenStreetMapIO.validate_decompressed_size(data, nothing, "Test") === nothing

    # Mismatch size: error
    @test_throws ArgumentError OpenStreetMapIO.validate_decompressed_size(data, Int32(5), "Test")
end
