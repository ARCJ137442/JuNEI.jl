module Console

using ..Utils
using ..CIN

export NARSConsole

"""从CIN到交互的示例界面：NARS控制台
- 🎯面向用户命令行输入（手动输入NAL语句）
- 📄内置CINProgram
- 🔬展示「如何封装CIN」的简单例子
"""
mutable struct NARSConsole
    program::CINProgram
    input_prompt::String
    launched::Bool # 用于过滤「无关信息」

    NARSConsole(
        type::NARSType, 
        executable_path::String, 
        input_prompt::String="Input: "
        ) = begin
        # 先构造自身
        console = new(
            CINCmdline(
                type, # 传入Program
                executable_path, # CINCmdline
                identity, # 占位符
            ),
            input_prompt, # 留存prompt
            false, # 默认未启动
        )
        # 通过更改内部Program的钩子，实现「闭包传输」类似PyNEI中「self」参数的目的
        out_hook!(console.program, line -> use_hook(console, line))
        return console
    end
end

"默认输出钩子（包括console对象「自身」）"
function use_hook(console::NARSConsole, line::String)
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
    
end