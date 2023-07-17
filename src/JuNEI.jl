module JuNEI

# 📝使用「Re-export」在using的同时export其中export的所有对象，避免命名冲突
using Reexport
#= 📄资料 from Claude 2
So in summary, Reexport lets you easily re-export parts of other modules's APIs. 
This avoids naming conflicts between modules
    and allows combining exported symbols 
    from multiple modules conveniently. 
The @reexport macro handles the underlying mechanics.
=#

"""
更新时间: 20230717 22:23:41

模块层级总览
- JuNEI
    - Utils
    - NAL
    - NARSElements
    - CIN
        - Templates
    - Console
    - Agent
    - Environment
"""

"直接使用「模块文件名 => 模块名」存储要include、using的模块信息"
const MODULE_FILES::Vector{Pair{String,String}} = [
    "Utils.jl"          =>      "Utils"
    "NAL.jl"            =>      "NAL"
    "Elements.jl"       =>      "NARSElements"
    "CIN.jl"            =>      "CIN"
    "Console.jl"        =>      "NARSConsole"
    "Agent.jl"          =>      "NARSAgent"
    "Environment.jl"    =>      "NARSEnvironment"
]

#= 使用eval批量导入 原例：
include("Utils.jl")
@reexport using .Utils
=#
for file_p::Pair{String, String} in MODULE_FILES

    # include指定文件（使用@__DIR__动态确定绝对路径）
    @eval $(joinpath(@__DIR__, file_p.first)) |> include
    
    # reexport「导入又导出」把符号全导入的同时，对外暴露
    @eval @reexport using .$(Symbol(file_p.second))
end

"包初始化：从Project.toml中获取&打印包信息"
function __init__() # 【20230717 22:23:10】💭很仿Python
    project_file_content = read(
        joinpath(dirname(@__DIR__), "Project.toml"), # 获得文件路径
        String # 目标格式：字符串
    )
    # 使用正则匹配，这样就无需依赖TOML库
    name = match(r"name *= *\"(.*?)\"", project_file_content)[1]
    version = match(r"version *= *\"(.*?)\"", project_file_content)[1]
    # 打印信息（附带颜色）【20230714 22:25:42】现使用`printstyled`而非ANSI控制字符
    printstyled(
        "$name v$version\n", # 例：「JuNEI v0.2.0」
        bold=true,
        color=:light_green
    )
end

# using .CIN.Templates # 【20230717 22:19:54】这个应该在最初using时就已导入了
"使用PackageCompiler打包时的主函数"
function julia_main()::Cint

    # 启动终端
    console = Console(
        inputType("NARS Type: "),
        input"Executable Path: ",
    )

    launch!(console)

    return 0
end

end
