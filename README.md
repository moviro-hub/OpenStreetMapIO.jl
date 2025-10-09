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

## Data Sources

OSM data are available from various sources:
- [Geofabrik](https://download.geofabrik.de/) - Regional extracts
- [Overpass API](https://overpass-api.de/) - Online query service
- [Planet.osm](https://planet.openstreetmap.org/) - Full planet data

License: MIT
