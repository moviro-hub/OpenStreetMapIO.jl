#!/usr/bin/env julia

"""
Script to update protobuf files from .proto definitions.

This script regenerates the Julia protobuf code from the .proto files.
Run this script whenever the .proto files are updated.

Usage:
    julia scripts/update_protobuf.jl
"""

using Pkg
using ProtoBuf

# Activate the project environment
Pkg.activate(".")

println("Updating protobuf files...")

# Get the project root directory
project_root = dirname(@__DIR__)
proto_dir = joinpath(project_root, "src", "protobuf", "proto")
output_dir = joinpath(project_root, "src", "protobuf")

# Check if proto files exist
fileformat_proto = joinpath(proto_dir, "fileformat.proto")
osmformat_proto = joinpath(proto_dir, "osmformat.proto")

if !isfile(fileformat_proto)
    error("fileformat.proto not found at $fileformat_proto")
end

if !isfile(osmformat_proto)
    error("osmformat.proto not found at $osmformat_proto")
end

println("Found proto files:")
println("  - $fileformat_proto")
println("  - $osmformat_proto")

# Generate Julia code from proto files
println("Generating Julia code from proto files...")

try
    protojl(["fileformat.proto", "osmformat.proto"], proto_dir, output_dir)
    println("✓ Successfully generated protobuf files")

    # List generated files
    generated_files = ["fileformat_pb.jl", "osmformat_pb.jl"]

    println("Generated files:")
    for file in generated_files
        file_path = joinpath(output_dir, file)
        if isfile(file_path)
            println("  ✓ $file")
        else
            println("  ✗ $file (not found)")
        end
    end

    println("\nProtobuf files updated successfully!")
    println("You can now run the tests to verify everything works correctly.")

catch e
    println("✗ Error generating protobuf files:")
    println("  $e")
    exit(1)
end
