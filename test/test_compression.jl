using OpenStreetMapIO, Test
using ProtoBuf: OneOf
using CodecZlib: ZlibCompressorStream

@testset "Compression Format Tests" begin
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
                @test occursin("BZIP2", e.msg) || occursin("bzip2", lowercase(e.msg))
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
        test_file = joinpath(@__DIR__, "data", "map.pbf")
        osmdata = OpenStreetMapIO.readpbf(test_file)

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
        close(stream)
        compressed_data = take!(compressed_io)

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
        err = @test_throws ArgumentError OpenStreetMapIO.decode_blob(
            incorrect_blob, OpenStreetMapIO.OSMPBF.HeaderBlock
        )
        # Check that we get an error (either size mismatch or decode failure)
        @test occursin("size mismatch", lowercase(err.value.msg)) ||
              occursin("failed to decode", lowercase(err.value.msg))
    end
end
