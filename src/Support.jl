"""
「支持」大模块
- 提供一些实用库，辅助代码开发
"""
module Support

# 📝使用「Re-export」在using的同时export其中export的所有对象，避免命名冲突
using Reexport

# 单独引入Utils，因为要用到里面的宏
include("Support/Utils.jl")
@reexport using .Utils

@include_N_reexport [
    "Support/NAL.jl"    =>    "NAL"
]

end
