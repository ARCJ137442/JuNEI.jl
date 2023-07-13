module JuNEI

# include(joinpath(@__DIR__, "Utils.jl"))
include("Utils.jl")
include("Elements.jl")
include("CIN.jl")
include("Console.jl")
include("Agent.jl")
include("Environment.jl")

"""
模块层级总览
- JuNEI
    - Utils
    - Elements
    - Program
    - Console
    - Agent
    - Environment
"""

const VERSION_JuNEI::VersionNumber = v"0.0.1"

function __init__()
    println("JuNEI v$VERSION_JuNEI")
end

end