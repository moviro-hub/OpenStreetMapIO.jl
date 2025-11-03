__precompile__()
"""
    OpenStreetMapIO

A comprehensive OpenStreetMap (OSM) data file reader for Julia.

## Features

- Read OSM data from PBF (Protocol Buffer Format) files
- Read OSM data from XML files
- Query data from Overpass API
- Support for filtering data using callback functions
- Comprehensive type system for OSM elements (nodes, ways, relations)

## Main Functions

- [`readpbf`](@ref): Read OSM data from PBF files
- [`readosm`](@ref): Read OSM data from XML files
- [`queryoverpass`](@ref): Query data from Overpass API

## Data Types

- [`OpenStreetMap`](@ref): Container for complete OSM datasets
- [`Node`](@ref): OSM nodes (points) with coordinates and tags
- [`Way`](@ref): OSM ways (paths) as ordered node references
- [`Relation`](@ref): OSM relations (groupings) of elements
- [`BBox`](@ref): Geographic bounding box
- [`Position`](@ref): Geographic coordinates

## Examples

```julia
using OpenStreetMapIO

# Read from PBF file
osmdata = readpbf("map.pbf")

# Read from XML file
osmdata = readosm("map.osm")

# Query from Overpass API
bbox = BBox(54.0, 9.0, 55.0, 10.0)
osmdata = queryoverpass(bbox)

# Filter data using callbacks
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end
osmdata = readpbf("map.pbf", node_callback=keep_restaurants)
```
"""
module OpenStreetMapIO
using ProtoBuf: decode, ProtoDecoder, PipeBuffer
using CodecZlib: ZlibDecompressorStream
using CodecLz4: LZ4FrameDecompressorStream
using CodecZstd: ZstdDecompressorStream
using CodecXz: XzDecompressorStream
using Dates: unix2datetime, DateTime
using XML: XML
using Downloads: download
using Logging


export readpbf, readosm, queryoverpass
export OpenStreetMap, Node, Way, Relation, BBox, Position, Info

include("OSMPBF/OSMPBF.jl")
include("map_types.jl")
include("utils.jl")
include("load_pbf.jl")
include("load_xml.jl")
include("load_overpass.jl")

end
