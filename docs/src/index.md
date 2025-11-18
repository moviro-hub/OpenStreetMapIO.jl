# OpenStreetMapIO.jl

A comprehensive OpenStreetMap (OSM) data file reader for Julia.

## Features

- **File Format Support**: Read OSM data from both PBF and XML formats
- **Online Data Access**: Query OSM data directly from Overpass API
- **Callback Support**: Filter data during reading with custom callback functions


## Quick Start

```julia
using Pkg
Pkg.add(url="https://github.com/moviro-hub/OpenStreetMapIO.jl")
```

```julia
using OpenStreetMapIO

# Read OSM data from files
osmdata = read_pbf("map.pbf")  # PBF format
osmdata = read_osm("map.osm")  # XML format

# Query data from Overpass API
bbox = BBox(53.45, 9.95, 53.55, 10.05)
osmdata = query_overpass(bbox)

# Filter data during reading
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

osmdata = read_pbf("map.pbf", node_callback=keep_restaurants)
```

## License

This package is licensed under the MIT License. See [LICENSE.md](https://github.com/moviro-hub/OpenStreetMapIO.jl/blob/main/LICENSE.md) for details.
