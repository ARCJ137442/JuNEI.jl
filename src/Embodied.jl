"""
「具身」大模块
- 包括对游戏开放的智能体&环境
"""
module Embodied

# 静态（全局）变量
"决定是否要在运行时打印信息"
ENABLE_INFO::Bool = true

using ..Support.Utils: @include_N_reexport

@include_N_reexport [
    "Embodied/Elements.jl"       =>      "NARSElements"
]

include("Embodied/agent.jl")

include("Embodied/environment.jl")

end
