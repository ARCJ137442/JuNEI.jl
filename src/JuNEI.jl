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

# include(joinpath(@__DIR__, "Utils.jl"))
include("Utils.jl")
@reexport using .Utils # Utils不导出

include("Elements.jl")
@reexport using .NARSElements

include("CIN.jl")
@reexport using .CIN

include("Console.jl")
@reexport using .NARSConsole

include("Agent.jl")
@reexport using .NARSAgent

include("Environment.jl")
@reexport using .NARSEnvironment

"""
模块层级总览
- JuNEI
    - Utils
    - NARSElements
    - CIN
        - Templates
    - Console
    - Agent
    - Environment
"""

"从Project.toml中获取版本"
function print_package_informations()
    # 获得文件路径
    project_file_path = joinpath(dirname(@__DIR__), "Project.toml")
    # 读取文档内容，转换成toml数据
    project_file_content = read(project_file_path, String)
    # 使用正则匹配，这样就无需依赖TOML库
    name = match(r"name *= *\"(.*?)\"", project_file_content)[1]
    version = match(r"version *= *\"(.*?)\"", project_file_content)[1]
    # 打印信息（附带颜色）【20230714 22:25:42】现使用`printstyled`而非ANSI控制字符
    printstyled(
        "$name v$version\n", 
        bold=true,
        color=:light_green
    )
end

"包初始化：打印包信息"
function __init__()
    print_package_informations()
end

using .CIN.Templates
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
