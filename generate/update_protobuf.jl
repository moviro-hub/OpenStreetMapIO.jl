#!/usr/bin/env julia

"""
Script to update protobuf files from .proto definitions.

This script regenerates the Julia protobuf code from the .proto files.
Run this script whenever the .proto files are updated.

Usage:
    julia generate/update_protobuf.jl
"""

using Pkg: Pkg
Pkg.activate(@__DIR__)

using ProtoBuf: ProtoBuf
using Downloads: Downloads

# Shared parameters
project_root = dirname(@__DIR__)
base_url = "https://raw.githubusercontent.com/openstreetmap/OSM-binary/master/osmpbf"
proto_files = ["fileformat.proto", "osmformat.proto"]
# Paths (single source of truth for proto directory)
proto_dir = joinpath(@__DIR__, "proto")
julia_output_dir = joinpath(project_root, "src")

# if not exists, create directories
mkpath(proto_dir)
mkpath(julia_output_dir)

# Download required .proto files into proto_dir
for file_name in proto_files
    url = string(base_url, "/", file_name)
    tmp = tempname()
    Downloads.download(url, tmp)
    dest = joinpath(proto_dir, file_name)
    mv(tmp, dest; force = true)
end

# Validate existence of required protos
for file_name in proto_files
    p = joinpath(proto_dir, file_name)
    if !isfile(p)
        error(file_name, " not found at ", p)
    end
end

try
    ProtoBuf.protojl(proto_files, proto_dir, julia_output_dir)
    # Optional minimal confirmation; keep output concise
    @info "Protobuf files updated."
catch e
    @error "Error generating protobuf files" exception = e
end
