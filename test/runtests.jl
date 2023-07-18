@show @__DIR__ # 显示当前工作路径
@show @__FILE__ # 显示当前运行的文件路径
@show dirname(@__DIR__) # 显示当前工作路径的父路径

push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

import JuNEI

ENV["JULIA_DEBUG"] = JuNEI # 启用DEBUG模式

"="^16 * "Test Start" * "="^16 |> println

# 模块&包 开发参考：https://blog.csdn.net/qq_39517117/article/details/127524706 #

const TEST_FILE_LIST::Vector{String} = [
    "test_utils.jl"
    "test_nal.jl"
    "test_elements.jl"
    "test_templates.jl"
    "test_CIN.jl"
    "test_junars.jl"
    "test_multiprocess.jl"
    "test_agent.jl"
    "test_console.jl"
]

for file::String in TEST_FILE_LIST
    @eval include($file)
end