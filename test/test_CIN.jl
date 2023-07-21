push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using Test

using JuNEI.CIN

macro softrun(expr)
    quote
        try
            $expr
        catch e
            @error e
        end
    end
end

"================Test for CIN================" |> println

# CINProgram

"测试用钩子函数"
hook(inputs...) = println("Hook! $inputs")

# 生成递推问句
N = 7
inputs = String[
    "<T$(i) --> T$(i+1)>."
    for i in 0:N
]
push!(inputs, "<T0 --> T$(N+1)>?")


EXECUTABLE_ROOT = joinpath(dirname(@__DIR__), "executables") # 获取文件所在目录的上一级目录（包根目录）

paths::Dict = Dict([
    :java => joinpath(EXECUTABLE_ROOT, "opennars.jar")
    :c => joinpath(EXECUTABLE_ROOT, "NAR.exe")
    :python => joinpath(EXECUTABLE_ROOT, "main.exe")
])

@testset "OpenNARS" begin

    @info "正在启动OpenNARS"

    type::NARSType = NARSType"OpenNARS"
    on = CINProgram(type, paths[:java], hook)

    out = String[]
    out_hook!(on) do s
        push!(out, s)
    end

    @test !isAlive(on)

    @show on
    launch!(on)
    @test isAlive(on)

    sleep(1)

    put!(on, inputs)
    cycle!(on, 50)
    # @test cached_inputs(on) |> !isempty

    sleep(2)
    
    # 测试是否有回应 ？疑难杂症：这里就可以输出到out，但下面的ONA就不可以
    @test out .|> (s -> contains(s, "Answer: <T0 --> T8>.")) |> any

    @info "开始终止程序。。。"
    
    # 【20230714 13:44:34】暂时还需要taskkill
    @softrun `taskkill -f -im java.exe` |> run
    @softrun `taskkill -f -im javaw.exe` |> run

    terminate!(on)
    @test !isAlive(on)
end

@testset "ONA" begin

    @info "正在启动ONA"
    
    ona = CINProgram(
        NARSType"ONA",
        paths[:c],
    ) # 编码问题：系统找不到指定的路径。 "[...]\ONA\NAR.exe"

    out = String[]
    # out_hook!(ona) do hook
    out_hook!(ona) do s
        @show s
        push!(out, s)
    end
    @test ona.out_hook |> !isnothing

    @test launch!(ona) # launch!的返回值是「是否启动成功」
    @test isAlive(ona)

    #= 疑难杂症
    不知为何，用「out_hook!(ona) do s
        @show s
        # @show args
        push!(out, content)
    end」就报错：
    MethodError(var"#3#5"(), ("Input: <T5 --> T6>. Priority=1.000000 Truth: frequency=1.000000, confidence=0.900000",), 0x00000000000082d1)
    =#

    sleep(1)

    put!(ona, inputs)
    
    cycle!(ona, 50) # 要给它足够的时间？
    
    sleep(2)

    # 测试是否有正确回应
    @show out
    @test out .|> (s -> contains(s, "Answer: <T0 --> T8>.")) |> any

    @info "开始终止程序。。。"
    
    # 【20230714 13:44:34】暂时还需要taskkill
    @softrun `taskkill -f -im NAR.exe` |> run
    
    terminate!(ona) # 直接在这里就卡住了
    @test !isAlive(ona)
end

sleep(2)

@testset "Python" begin

    @info "正在启动NARS Python"
    
    np = CINProgram(NARSType"Python", paths[:python])
    @test np.type == NARSType"Python"
    out = nothing
    out_hook!(np, x -> (out=x))
    launch!(np)

    sleep(2)

    put!(np, 
    [
        "(" * s[2:end-2] * ")" * s[end]
        for s in inputs
    ])

    use_hook(np, "OUT: ({This} -> [Test]). %1.00;0.90%")

    sleep(5)

    @test !isnothing(out)
    
    # 【20230714 13:44:34】暂时还需要taskkill
    @softrun `taskkill -f -im main.exe` |> run
    
    terminate!(np)
    @test !isAlive(np)
end
