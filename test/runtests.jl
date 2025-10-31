include("test_helpers.jl")

# Core functionality tests
include("test_data_types.jl")

# Core reading functionality tests
include("test_load_pbf.jl")
include("test_load_xml.jl")
# Be a brave citizen, only enable while working on Overpass API call functions
# include("test_load_overpass.jl")
include("test_callbacks.jl")

# Protobuf tests
include("test_protobuf.jl")
