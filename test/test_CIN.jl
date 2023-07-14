push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

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

begin "OpenNARS"

    @info "正在启动OpenNARS"

    type::NARSType = NARSType"OpenNARS"
    on = CINProgram(type, paths[:java], hook)

    @assert !isAlive(on)

    @show on
    launch!(on)
    @assert isAlive(on)

    sleep(1)

    put!(on, inputs)
    cycle!(on, 50)
    # @assert cached_inputs(on) |> !isempty

    sleep(2)

    @info "开始终止程序。。。"
    
    # 【20230714 13:44:34】暂时还需要taskkill
    @softrun `taskkill -f -im java.exe` |> run
    @softrun `taskkill -f -im javaw.exe` |> run

    terminate!(on)
    @assert !isAlive(on)
end

begin "ONA"

    @info "正在启动ONA"
    
    ona = CINProgram(
        NARSType"ONA",
        paths[:c],
    ) # 编码问题：系统找不到指定的路径。 "[...]\ONA\NAR.exe"
    
    @show launch!(ona) isAlive(ona)
    @show out_hook!(ona, hook)
    
    sleep(1)

    put!(ona, inputs)
    
    cycle!(ona, 5)
    
    sleep(2)

    @info "开始终止程序。。。"
    
    # 【20230714 13:44:34】暂时还需要taskkill
    @softrun `taskkill -f -im NAR.exe` |> run
    
    terminate!(ona) # 直接在这里就卡住了
    @assert !isAlive(ona)
end

sleep(2)

begin "Python"

    @info "正在启动NARS Python"
    
    np = CINProgram(NARSType"Python", paths[:python])
    @assert np.type == NARSType"Python"
    out_hook!(np, hook)
    launch!(np)

    sleep(2)

    put!(np, 
    [
        "(" * s[2:end-2] * ")" * s[end]
        for s in inputs
    ])

    use_hook(np, "OUT: ({This} -> [Test]). %1.00;0.90%")

    sleep(5)
    
    # 【20230714 13:44:34】暂时还需要taskkill
    @softrun `taskkill -f -im main.exe` |> run
    
    terminate!(np)
    @assert !isAlive(np)
end
