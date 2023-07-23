"""
「接口」大模块
- 面向CIN的各类对接
"""
module Interface

using ..Support.Utils: @include_N_reexport
@include_N_reexport [
    "Interface/CIN.jl"            =>      "CIN"
    "Interface/Console.jl"        =>      "NARSConsole"
]

end
