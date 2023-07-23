"""
「注册」大模块
- 提供可扩展的具体CIN接口
"""
module Register

using ..Support.Utils: @include_N_reexport
@include_N_reexport [
    "Register/Templates.jl"     =>     "Templates"
    "Register/CINRegistry.jl"       =>     "CINRegistry"
]

end
