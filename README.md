# OpenStreetMapIO.jl

[Documentation](https://moviro-hub.github.io/OpenStreetMapIO.jl/)

A comprehensive OpenStreetMap (OSM) data file reader for Julia.

## Features

- **File Format Support**: Read OSM data from both PBF and XML formats
- **Online Data Access**: Query OSM data directly from Overpass API
- **Callback Support**: Filter data during reading with custom callback functions

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/moviro-hub/OpenStreetMapIO.jl")
```

## Basic Usage

### Reading OSM Files

Example data can be found in the  `.test/data` directory of this repository.

```julia
using OpenStreetMapIO

# Read PBF file
osmdata = readpbf("map.pbf")

# Read XML file
osmdata = readosm("map.osm")

# Query data from Overpass API
bbox = BBox(53.45, 9.95, 53.55, 10.05)  # lat_min, lon_min, lat_max, lon_max
osmdata = queryoverpass(bbox)
```

### Working with Data

```julia
# Access nodes
for (id, node) in osmdata.nodes
    println("Node $id at ($(node.position.lat), $(node.position.lon))")
    if node.tags !== nothing
        println("  Tags: $(node.tags)")
    end
    if node.info !== nothing
        println("  Version: $(node.info.version)")
    end
end

# Access ways
for (id, way) in osmdata.ways
    println("Way $id with $(length(way.refs)) nodes")
    if way.positions !== nothing  # LocationsOnWays feature
        println("  Has embedded coordinates")
    end
end

# Access metadata
if haskey(osmdata.meta, "bbox")
    bbox = osmdata.meta["bbox"]
    println("Bounding box: $(bbox.bottom_lat), $(bbox.left_lon) to $(bbox.top_lat), $(bbox.right_lon)")
end
```

### Usage with Callbacks

```julia
# Filter data during reading
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

osmdata = readpbf("map.pbf", node_callback=keep_restaurants)

osmdata = readosm("map.osm", node_callback=keep_restaurants)
```

## Data Types

- **`OpenStreetMap`**: Container with `nodes`, `ways`, `relations`, and `meta` dictionaries
- **`Node`**: Point with `position` (Position), `tags`, and optional `info`
- **`Way`**: Ordered list with `refs` (node IDs), `tags`, optional `info` and `positions`
- **`Relation`**: Group with `refs`, `types`, `roles`, `tags`, and optional `info`
- **`Position`**: Geographic coordinate with `lat` and `lon` (Float64)
- **`BBox`**: Bounding box with `bottom_lat`, `left_lon`, `top_lat`, `right_lon`
- **`Info`**: Metadata with `version`, `timestamp`, `changeset`, `uid`, `user`, `visible`

## Data Sources

OSM data are available from various sources:
- [Geofabrik](https://download.geofabrik.de/) - Regional extracts
- [Overpass API](https://overpass-api.de/) - Online query service
- [Planet.osm](https://planet.openstreetmap.org/) - Full planet data

License: MIT
