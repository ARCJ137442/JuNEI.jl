mutable struct NARSConsole
    program::NARSProgram
    input_prompt::String
    launched::Bool # 用于过滤「无关信息」
    out_hook::Function # 用于闭包检测「是否启动」

    NARSConsole(
        type::NARSType, 
        executable_path::String, 
        input_prompt::String="Input: "
        ) = begin
        # 先构造自身
        console = new(
            NARSCmdline(
                type, # 传入Program
                executable_path, # NARSCmdline
                out_hook_console, # 传入Program
            ),
            input_prompt, # 留存prompt
            false, # 默认未启动
            identity, # 占位符
        )
        # 通过更改内部Program的钩子，实现「闭包传输」类似PyNEI中「self」参数的目的
        out_hook!(console.program, line -> out_hook_console(console, line))
        return console
    end
end

"默认输出钩子（包括console对象「自身」）"
function out_hook_console(console::NARSConsole, line::String)
    console.launched && println(line)
end

function launch!(console::NARSConsole)
    launch!(console.program) # 启动CIN程序
    console!(console)
end

function console!(console::NARSConsole)
    while true
        console.launched = true
        print(console.input_prompt)
        input = readline(stdin)
        put!(console.program, input)
    end
end