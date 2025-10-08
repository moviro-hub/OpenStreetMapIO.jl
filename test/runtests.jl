include("test_helpers.jl")

# Core functionality tests
include("test_data_types.jl")

# Core reading functionality tests
include("test_readpbf.jl")
include("test_readosm.jl")
# Be a brave citizen, only enable wile working on Overpass API call functions
# include("test_queryoverpass.jl")
include("test_callbacks.jl")

# Protobuf tests
include("test_protobuf.jl")
