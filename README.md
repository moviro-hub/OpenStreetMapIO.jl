# OpenStreetMapIO.jl

A comprehensive OpenStreetMap (OSM) data file reader for Julia.

## Features

- **File Format Support**: Read OSM data from both PBF (Protocol Buffer Format) and XML formats
- **Online Data Access**: Query OSM data directly from Overpass API
- **Callback Support**: Filter data during reading with custom callback functions

## Installation

```julia
using Pkg
Pkg.add("OpenStreetMapIO")
```

## Basic Usage

### Reading OSM Files

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

### Working with OSM Data

```julia
# Access nodes, ways, and relations
node = osmdata.nodes[1675598406]
way = osmdata.ways[889648159]
relation = osmdata.relations[12475101]

# Access node coordinates
println("Node coordinates: $(node.latlon.lat), $(node.latlon.lon)")

# Access way node references
println("Way has $(length(way.refs)) nodes")

# Access relation members
println("Relation has $(length(relation.members)) members")
```

### Advanced Usage with Callbacks

```julia
# Filter data during reading
function keep_restaurants(node)
    if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

osmdata = readpbf("map.pbf", node_callback=keep_restaurants)

# Callbacks also work with XML files
osmdata = readosm("map.osm", node_callback=keep_restaurants)
```

## Data Sources

OSM data are available from various sources:
- [Geofabrik](https://download.geofabrik.de/) - Regional extracts
- [Overpass API](https://overpass-api.de/) - Online query service
- [Planet.osm](https://planet.openstreetmap.org/) - Full planet data

## Data Model

The package provides the following data structures:

- `Node`: Point with latitude/longitude and optional tags
- `Way`: Ordered list of node references forming a path
- `Relation`: Group of elements with roles and types
- `BBox`: Bounding box for geographic filtering
- `LatLon`: Latitude/longitude coordinate pair

For detailed information about the OSM data model, see:
- [OSM PBF Format](https://wiki.openstreetmap.org/wiki/PBF_Format)
- [OSM XML Format](https://wiki.openstreetmap.org/wiki/OSM_XML)

## Development

### Updating Protobuf Files

The package uses Protocol Buffers for reading PBF files. The protobuf definitions are located in `src/protobuf/proto/` and the generated Julia code is in `src/protobuf/`.

To update the protobuf files:

```bash
julia scripts/update_protobuf.jl
```

This will regenerate the Julia protobuf code from the `.proto` files.

## Development Setup

### Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality and formatting. To set up the pre-commit hooks:

```bash
# Run the setup script
./scripts/setup_precommit.sh

# Or manually install pre-commit and the hooks
pip install pre-commit
pre-commit install
```

The pre-commit hooks will:
- Automatically format Julia code with Runic.jl before each commit
- Ensure consistent code style across the project

To test the hooks manually:
```bash
pre-commit run --all-files
```

## API Reference

### Core Functions
- `readpbf(filename; node_callback, way_callback, relation_callback)` - Read PBF file
- `readosm(filename; node_callback, way_callback, relation_callback)` - Read XML file
- `queryoverpass(bbox|latlon, radius|bounds; timeout)` - Query Overpass API

### Data Types
- `OpenStreetMap` - Main data structure containing nodes, ways, relations, and metadata
- `Node` - Point with latitude/longitude and optional tags
- `Way` - Ordered list of node references forming a path
- `Relation` - Group of elements with roles and types
- `BBox` - Bounding box for geographic filtering
- `LatLon` - Latitude/longitude coordinate pair


License: MIT
