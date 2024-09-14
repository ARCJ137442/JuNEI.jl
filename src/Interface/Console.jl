"""
CIN封装示例：可调用的控制台窗口
- 可选的「外接Websocket服务器」功能
  - 不作为直接的包依赖
"""
module NARSConsole

using ...Support.Utils

import ..CIN: launch!, terminate!, out_hook!
using ..CIN

export Console
export launch!, console!

"""从CIN到交互的示例界面：NARS控制台
- 🎯面向用户命令行输入（手动输入NAL语句）
- 📄内置CINProgram
- 🔬展示「如何封装CIN」的简单例子
"""
mutable struct Console

    # 内置程序（引用）
    const program::CINProgram

    input_prompt::String
    launched::Bool # 用于过滤「无关信息」

    Console(
        type::NARSType,
        executable_path::String,
        input_prompt::String="Input: "
    ) = begin
        # 先构造自身
        console = new(
            CINProgram( # 使用CIN.jl/CINProgram的构造方法，自动寻找合适类型
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

using JSON: json
"默认输出钩子（包括console对象「自身」）"
function use_hook(console::Console, line::String)
    console.launched && println(line)
    # 发送到客户端 #
    # * 默认解析方法
    global server, connectedSocket
    if !isnothing(server)
        objs = []
        head = findfirst(r"\w+:", line) # EXE: XXXX
        # 若为有效的「NARS输出类型」（非`NARSOutputType.OTHER`）
        if !isnothing(head)
            type = line[head][begin:end-1]
            content = line[nextind(content, last(head), 1):end]
        else
            type = NARSOutputType.OTHER
            content = line
        end
        # 使用并传输输出
        push!(objs, Dict(
            "interface_name" => "JuNEI",
            "output_type" => type,
            "content" => content
        ))
        # 传输
        for ws in connectedSocket
            send(ws, json(objs))
        end
    end
end

"配置WS服务器信息"
function configServer(
    console::Console,
    host::Union{AbstractString,Nothing}=nothing,
    port::Union{Int,Nothing}=nothing,
)::Console
    needServer = !isnothing(host) || !isnothing(port) || !isempty(input("Server? (\"\") "))
    if needServer
        if isnothing(host)
            hostI = input("Host (127.0.0.1): ")
            host = !isempty(hostI) ? hostI : "127.0.0.1"
        end

        if isnothing(port)
            port = tryparse(Int, input("Port (8765): "))
            port = isnothing(port) ? 8765 : port
        end

        launchWSServer(console, host, port)
    end
    return console
end

try
    using SimpleWebsockets: WebsocketServer, Condition, listen, notify, serve, send
catch e
    @warn "JuNEI: 包「SimpleWebsockets」未能成功导入，WebSocket服务将无法使用！"
end
server = nothing
connectedSocket = []
function launchWSServer(console::Console, host::String, port::Int)

    global server, connectedSocket
    server = WebsocketServer()
    ended = Condition()

    listen(server, :client) do ws

        # Julia自带侦听提示
        @info "Websocket connection established with ws=$ws"
        push!(connectedSocket, ws)

        listen(ws, :message) do message
            # 直接处理
            put!(console.program, message)
        end

        listen(ws, :close) do reason
            @warn "Websocket connection closed" reason...
            notify(ended)
        end

    end

    listen(server, :connectError) do err
        notify(ended, err, error=true)
    end

    # @show server

    @async serve(server, port, host)
    # wait(ended) # ! 实际上可以直接异步
end

"启动终端"
function launch!(
    console::Console,
    host::Union{AbstractString,Nothing}=nothing,
    port::Union{Int,Nothing}=nothing,
)
    launch!(console.program) # 启动CIN程序
    configServer(console, host, port)
    console!(console)
end

"开始终端循环"
function console!(console::Console)
    while true
        console.launched = true
        inp = input(console.input_prompt)
        put!(console.program, inp)
    end
end

"终止终端"
terminate!(console::Console) = terminate!(console.program)

end
