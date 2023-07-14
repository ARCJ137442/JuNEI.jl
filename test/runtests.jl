@show @__DIR__ # 显示当前工作路径
@show @__FILE__ # 显示当前运行的文件路径
@show dirname(@__DIR__) # 显示当前工作路径的父路径

push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

# 模块&包 开发参考：https://blog.csdn.net/qq_39517117/article/details/127524706 #

include("test_utils.jl")
include("test_elements.jl")
include("test_templates.jl")
include("test_CIN.jl")
include("test_multiprocess.jl")
include("test_agent.jl")
include("test_console.jl")
