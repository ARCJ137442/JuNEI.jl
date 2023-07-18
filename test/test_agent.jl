push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI
using JuNEI.Utils

# type::NARSType = inputType()
type::NARSType = NARSType"OpenNARS"
@show @__DIR__

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
agent = Agent(
    type,
    path
)

activate!(agent)

1 |> sleep

register!(agent, Goal"good")

register!(agent, Operation"left")
register!(agent, Operation"right")

1 |> sleep

NAL_SENTENCES::String = raw"""
<{t001} --> [opened]>! :|:
<{t001} --> door>.
<(&/, <(*, {SELF}, {t002}) --> hold>, <(*, {SELF}, {t001}) --> at>, (^open, {SELF}, {t001})) =/> <{t001} --> [opened]>>.
<(*, {t002}, {t001}) --> key-of>.
<(&/, <(*, {SELF}, {t002}) --> reachable>, (^pick, {SELF}, {t002})) =/> <(*, {SELF}, {t002}) --> hold>>.
<(&|, <(*, $x, #y) --> on>, <(*, {SELF}, #y) --> at>) =|> <(*, {SELF}, $x) --> reachable>>.
<(*, {t002}, {t003}) --> on>. :|:
<{t003} --> desk>.
<(^go-to, {SELF},$x) =/> <(*, {SELF}, $x) --> at>>.
""" # ONA似乎不能执行操作？OpenNARS就可以

put!(agent,
    (split(NAL_SENTENCES, "\n") .|> String)...
)

1 |> sleep

put!(agent,
    Perception"right"SELF,
    Perception"left"SELF
)

1 |> sleep

cycle!(agent, 5)

5 |> sleep

terminate!(agent)

sleep(1)

# 暂且需要这样清理残留进程
@softrun `taskkill -f -im java.exe` |> run
@softrun `taskkill -f -im javaw.exe` |> run

"Agent test ended." |> println

sleep(0.5)