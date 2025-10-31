include("test_utils.jl")
using .TestUtils
using OpenStreetMapIO, Test

# Core functionality tests - matching src/ structure
include("test_map_types.jl")        # Tests for src/map_types.jl

# File loading tests - matching src/ structure
include("test_load_pbf.jl")         # Tests for src/load_pbf.jl
include("test_load_xml.jl")         # Tests for src/load_xml.jl
include("test_load_overpass.jl")    # Tests for src/load_overpass.jl
