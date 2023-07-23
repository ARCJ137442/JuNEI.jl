push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using Test

using JuNEI
using JuNEI.Utils

"================Test for Agent================" |> println

@testset "Agent" begin

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

    # 启动智能体
    agent = Agent(
        type,
        path
    )

    activate!(agent)

    1 |> sleep

    register!(agent, Goal"good")

    register!(agent, Operation"left")
    register!(agent, Operation"right")

    @test agent.goals[1] == (Goal"good", false) # (目标名, 是否负面)
    @test (Operation"left", Operation"right") ⊆ keys(agent.operations)

    1 |> sleep

    """
    NAL-8 测试
    
    源：https://github.com/opennars/opennars/wiki/Procedural-Inference
    预期结果：
        EXECUTE: ^go-to({SELF},{t003})
        EXECUTE: ^pick({SELF},{t002})
        EXECUTE: ^go-to({SELF},{t001})
        EXECUTE: ^open({SELF},{t001})
    """
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

    @show agent.operations

    @test [
        # Operation(Symbol("go-to"), "{SELF}", "{t003}") # 自己 去到 t003（桌子）
        Operation(:pick, "{SELF}", "{t002}") # （主要）自己 拿 t002（钥匙）
        # Operation(Symbol("go-to"), "{SELF}", "{t001}") # 自己 去到 t001（门）
        # Operation(:open, "{SELF}", "{t001}") # 自己 打开 t001（门）
    ] ⊆ keys(agent.operations)

    terminate!(agent)

    @test !isAlive(agent)

    sleep(1)

    # 暂且需要这样清理残留进程
    @softrun `taskkill -f -im java.exe` |> run
    @softrun `taskkill -f -im javaw.exe` |> run

    "Agent test ended." |> println

    sleep(0.5)
end