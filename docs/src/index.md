# OpenStreetMapIO.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://moviro.github.io/OpenStreetMapIO.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://moviro.github.io/OpenStreetMapIO.jl/dev)
[![Build Status](https://github.com/moviro-hub/OpenStreetMapIO.jl/workflows/CI/badge.svg)](https://github.com/moviro-hub/OpenStreetMapIO.jl/actions)
[![Coverage](https://codecov.io/gh/moviro/OpenStreetMapIO.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/moviro/OpenStreetMapIO.jl)

A comprehensive Julia package for reading and processing OpenStreetMap data in various formats.

## Features

- **File Format Support**: Read OSM data from both PBF (Protocol Buffer Format) and XML formats
- **Online Data Access**: Query OSM data directly from Overpass API
- **Callback Support**: Filter data during reading with custom callback functions

## Quick Start

```julia
using OpenStreetMapIO

# Read OSM data from files
osmdata = readpbf("map.pbf")  # PBF format
osmdata = readosm("map.osm")  # XML format

# Query data from Overpass API
bbox = BBox(53.45, 9.95, 53.55, 10.05)
osmdata = queryoverpass(bbox)

# Filter data during reading
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

osmdata = readpbf("map.pbf", node_callback=keep_restaurants)
```

## Installation

```julia
using Pkg
Pkg.add("OpenStreetMapIO")
```

## Data Model

The package provides a complete implementation of the OpenStreetMap data model:

- **`Node`**: Points with latitude/longitude coordinates and optional tags
- **`Way`**: Ordered lists of node references forming paths or areas
- **`Relation`**: Groups of elements with roles and types
- **`BBox`**: Geographic bounding boxes for spatial filtering
- **`LatLon`**: Latitude/longitude coordinate pairs
- **`OpenStreetMap`**: Container for complete OSM datasets

## Supported Formats

- **PBF (Protocol Buffer Format)**: Binary format, most efficient for large datasets
- **XML**: Human-readable format, compatible with standard OSM tools
- **Overpass API**: Online query service for real-time data access

## Performance

OpenStreetMapIO.jl is optimized for performance:

- Efficient memory usage with streaming processing
- Support for large datasets (tested with planet-scale data)
- Optimized protobuf parsing for PBF files
- Callback-based filtering to reduce memory footprint

## License

This package is licensed under the MIT License. See [LICENSE.md](https://github.com/moviro-hub-hub/OpenStreetMapIO.jl/blob/main/LICENSE.md) for details.

## Contributing

Contributions are welcome! Please see our [Developer Guide](developer.md) for information on contributing to the project.
