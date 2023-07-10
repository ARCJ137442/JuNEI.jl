
include("Utils.jl")
include("Elements.jl")
include("Program.jl")
include("Console.jl")
include("Agent.jl")
include("Environment.jl")

"""
文件include结构：
- JuNEI
    - Utils
    - Elements
    - Program
        - CIN_Implements
            - CIN_Templetes
                - CIN_Register_Templete
            - CIN_Register_Implement
    - Console
    - Agent
    - Environment
"""

VERSION_JuNEI::VersionNumber = v"0.0.1"

println("JuNEI v$VERSION_JuNEI")
