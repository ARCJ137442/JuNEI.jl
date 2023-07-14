push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

import JuNEI: isAlive, put!, terminate!, launch!

begin "附加功能"
    
    assemble_cmd(exe_path::String, args::Vector{String})::Cmd = `$exe_path $(join(args))`
    
    function showproperties(target)
        @show target
        for propertyname in propertynames(target)
            "$target.$propertyname = $(getproperty(target, propertyname))" |> println
        end
    end

    (a) ⊂ (b) = contains(b, a)
end

# 调用函数来执行外部exe文件，并获取结果

mutable struct Program
    exe_path::String
    args::Vector{String}
    process::Union{Base.Process, Nothing}

    Program(exe_path, args=String[], process=nothing) = new(exe_path, args, process)
end

begin "方法区"

    "获取完整的程序执行指令"
    exe_cmd(program::Program) = "$(program.exe_path) $(join(program.args))"
    
    isAlive(program::Program)::Bool = 
        hasproperty(program, :process) && # 是否有
        isdefined(program, :process) && # 定义了吗
        !isnothing(program.process) && # 是否为空
        program.process.exitcode != 0 && # 退出码正常吗
        process_running(program.process) && # 是否在运行
        !process_exited(program.process) # 没退出吧
    # 先判断「有无属性」，再判断「是否定义」，最后判断「是否为空」
    # TODO：避免用符号「:process」导致「无法自动重命名」的问题
    # 进展：没能编写出类似「@soft_isnothing_property cmd.process」自动化（尝试用「hasproperty($object, property_name)」插值「自动转换成Symbol」混乱，报错不通过）

    "置入命令（抽象）"
    put!(program::Program, input::String) = println(program.process.in, input)

    "(WIP)程序终止"
    function terminate!(program::Program)
        # @show close(process)
        @assert getpid(program.process) != 0
        @show kill(program.process)
    
        program.process.exitcode = 0
        @assert program.process.exitcode == 0
        # @show close(process.in) close(process.out) # close这两个会卡
    end
end

EXECUTABLE_ROOT = joinpath(dirname(@__DIR__), "executables") # 获取文件所在目录的上一级目录（包根目录）

paths::Dict = Dict([
    :java => joinpath(EXECUTABLE_ROOT, "opennars.jar")
    :c => joinpath(EXECUTABLE_ROOT, "NAR.exe")
    :python => joinpath(EXECUTABLE_ROOT, "main.exe")
])

path = paths[:c]

prog::Program = Program(
    path,
    String["shell", ""]
)


@show prog

inputs = path == paths[:python] ? String[
    "(A --> B).", 
    "(B --> C).", 
    "(C --> D).", 
    "(A --> D)?"
] : String[
    "<A --> B>.", 
    "<B --> C>.", 
    "<C --> D>.", 
    "<A --> D>?"
]

cmd = assemble_cmd(prog.exe_path, prog.args)

# https://discourse.juliacn.com/t/topic/5039/2

"输出处理钩子"
function hook(line::String)
    if "Answer" ⊂ line
        "Answer! $line" |> println
    else
        !isempty(line) && println("Hook! $line")
    end
end

"异步读取输出"
function async_read_out(program::Program)
    while program.process.exitcode != 0
        program.process |> readline |> hook
    end
end

"主运行钩子"
function handleProcess(program::Program)

    process::Base.Process = open(`cmd`, "r+")
    # process::Base.Process = open(`cmd`, "r+"; encoding="UTF-8")
    
    program.process = process

    @show isAlive(program)

    showproperties(process)
    showproperties(process.out)

    # close(process)

    "now reading..." |> println
    
    # 开启监听
    @async async_read_out(program)

    5 |> sleep

    # 写
    # !!!不能用write（这个Process继承了IO，但实际上没有任何行为），要用println
    # println：看起来像是一个「输出操作」，但实际上可以作为输入端输入命令（cmd测试成功）
    put!( # 输入初始指令
        program,
        exe_cmd(prog),
        # "java -Xmx1024m -jar $jar_path" # opennars 测试成功✅
    )

    0.5 |> sleep

    for inp ∈ inputs
        put!(program, "$inp\n")
        # @show inp 
    end

    10 |> sleep

    @show isAlive(program)

    terminate!(program)

    @show isAlive(program)

    process |> showproperties

    return
end

launch!(prog::Program) = @async handleProcess(prog)

@show isAlive(prog)

launch!(prog)
    
20 |> sleep

"return!" |> println