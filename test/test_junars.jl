push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using Test

import JuNEI
using JuNEI.CIN

ENV["JULIA_DEBUG"] = JuNEI

"================Test for Junars================" |> println

@testset "Junars" begin
    hook_f(content) = println("Hook! Junars says: $content")

    FOLDER::String = "OpenJunars-main"

    cj = CINJunars(
        "../../../$FOLDER", # 这里使用了相对路径，仅在此计算机中有效（其它环境需自行更改）
        hook_f
    )

    launch!(cj, "../../../../$FOLDER", "../../$FOLDER")
    # @show cj # 启动后一打印一大片。。。

    # 使用while+sleep等待Junars加载完毕
    while !isAlive(cj)
        sleep(1)
    end

    cjput(inp) = put!(cj, inp)

    [
        "<{SELF} --> [good]>."
        "<{SELF} --> [left]>."
    ] |> cjput
    cycle!(cj, 5)

    [
        "<A --> B>."
        "<A --> C>."
        "<B --> C>?"
    ] |> cjput
    @show cj.oracle.taskbuffer
    @test isAlive(cj)

    ENV["JULIA_DEBUG"] = Main # 启用DEBUG模式

    cycle!(cj, 20)

    #= 目前三段论推理可能会出现错误
        ERROR: LoadError: UndefVarError: `conversion` not defined
        Stacktrace:
        [1] matchreverse(j1::Junars.Gene.Inheritance, j2::Junars.Gene.Inheritance, nar::Junars.Admins.Nar)
        @ Junars.Inference [...]/OpenJunars/src/inference/syllogism.jl:204
        [2] syllogisim_aa(j1::Junars.Gene.Inheritance, j2::Junars.Gene.Inheritance, figure::Int64, nar::Junars.Admins.Nar)
        @ Junars.Inference [...]/OpenJunars/src/inference/syllogism.jl:94
        [3] syllogisim(j1::Junars.Gene.Inheritance, j2::Junars.Gene.Inheritance, nar::Junars.Admins.Nar)
        @ Junars.Inference [...]/OpenJunars/src/inference/syllogism.jl:30
    =#

    showtracks(cj)

    sleep(3)

    @info "终止Junars。。。"

    terminate!(cj)

end