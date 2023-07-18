push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI

while true
    # type::NARSType = NARSType"ONA"
    global type::NARSType = inputType("NARS Type(OpenNARS/ONA/Python/Junars): ")
    isempty(type) && (type = NARSType"ONA")
    # 检验合法性
    isvalid(type) && break
    printstyled("Invalid Type!\n"; color=:red)
end

# 自动决定exe路径

EXECUTABLE_ROOT = joinpath(dirname(@__DIR__), "executables") # 获取文件所在目录的上一级目录（包根目录）
JER(name) = joinpath(EXECUTABLE_ROOT, name)

paths::Dict = Dict([
    NARSType"OpenNARS" => "opennars.jar" |> JER
    NARSType"ONA" => "NAR.exe" |> JER
    NARSType"Python" => "main.exe" |> JER
    NARSType"Junars" => raw"..\..\..\..\OpenJunars-main"
])

path = paths[type]

# 启动终端
console = Console(
    type,
    path,
    "JuNEI.$(nameof(type))> ",
)

launch!(console)
