include("test_helpers.jl")

# Core functionality tests
include("test_data_types.jl")

# Core reading functionality tests
include("test_readpbf.jl")
include("test_readosm.jl")
# Be a brave citizen, only enable while working on Overpass API call functions
# include("test_queryoverpass.jl")
include("test_callbacks.jl")

# Protobuf tests
include("test_protobuf.jl")

# Compression format tests
include("test_compression.jl")

# Metadata extraction tests
include("test_metadata.jl")
