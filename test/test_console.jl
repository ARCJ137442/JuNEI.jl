push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "JuNEI/src") # 用于VSCode调试（项目根目录起）

using JuNEI

function input(prompt::String)::String
    print(prompt)
    readline()
end

function inputType()::NARSType
    NARSType(input("NARS Type: "))
end

type::NARSType = inputType()
# type::NARSType = NARSType"ONA"

# 自动决定exe路径

EXECUTABLE_ROOT = joinpath(dirname(@__DIR__), "executables") # 获取文件所在目录的上一级目录（包根目录）
JER(name) = joinpath(EXECUTABLE_ROOT, name)

paths::Dict = Dict([
    NARSType"OpenNARS" => "opennars.jar" |> JER
    NARSType"ONA" => "NAR.exe" |> JER
    NARSType"Python" => "main.exe" |> JER
])

path = paths[type]

# 启动终端
console = Console(
    type,
    path
)

launch!(console)
