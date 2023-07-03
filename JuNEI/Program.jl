"""有关NARS智能体(NARSAgent)与CIN(Computer Implement of NARS)的通信

前身：
- Boyang Xu, *NARS-FighterPlane*
- ARCJ137442, *NARS-FighterPlane v2.i alpha*

类の概览
- NARSType: 注册已有的CIN类型
- NARSProgram：抽象一个CIN通信接口
"""

# 导入「注册表」
include("CIN_Templetes.jl")

begin "NARSProgram" # 使用这个「代码块」将功能相近的代码封装到一起
    
    """具体与纳思通信的「程序」
    核心功能：负责与「NARS的具体计算机实现」沟通
    - 例：封装好的NARS程序包（支持命令行交互）
    """
    abstract type NARSProgram end
    
    # 抽象属性声明：使用外部构造方法
    NARSProgram(out_hook::Function, type::NARSType) = begin
        "Construct: NARSProgram with $out_hook, $type"
        return new(out_hook, type) # 返回所涉及类的一个实例（通用构造函数名称）
    end
    
    # 析构函数
    function finalize(program::NARSProgram)::Nothing
        terminate!(program)
    end
    
    # 程序相关 #
    
    "对外接口：函数钩子（公共属性实现为抽象方法）"
    out_hook(program::NARSProgram)::Function = program.out_hook
    
    "调用钩子（输出信息）"
    use_hook(program::NARSProgram, content::String) = out_hook(program)(content)
    
    "设置对外接口：函数钩子"
    function out_hook!(program::NARSProgram, newHook::Function)::Function
        program.out_hook = newHook
    end
    
    "（API）程序是否存活（开启）"
    isAlive(program::NARSProgram)::Bool = @abstractMethod # 抽象属性变为抽象方法
    
    "（API）启动程序"
    launch!(program::NARSProgram)::Nothing() = @abstractMethod
    
    "终止程序"
    function terminate!(program::NARSProgram)::Nothing
        program.out_hook = nothing # 置空
        println("NARSProgram terminate!")
    end
    
    # NAL相关 #

    "暴露一个「获取CIN类型」的外部接口（convert容易忘）"
    getNARSType(program::NARSProgram)::NARSType = convert(NARSType, program)

    "通过CIN直接获得「NARS语句模板」（convert容易忘）"
    function getSentenceTemplete(program::NARSProgram)::NARSSentenceTemplete
        convert(NARSSentenceTemplete, program) # 通过convert实现
    end
    
    "添加输入（NAL语句字符串）：对应PyNEI的「write_line」"
    function put!(program::NARSProgram, input::String) # 不强制Nothing
        push!(cached_inputs(program), input) # Vector只能push不能put
    end
    
    "（API）【立即？】增加NARS的工作循环：对应PyNEI的「add/update_inference_cycle」"
    cycle!(::NARSProgram, steps::Integer)::Nothing = @abstractMethod
    "无参数则是更新（使用属性「inference_cycle_frequency」）"
    cycle!(program::NARSProgram)::Nothing = 
        cycle!(program, program.inference_cycle_frequency)
    
    # 目标
    
    "添加目标（派发NARSGoal）"
    function put!(program::NARSProgram, goal::NARSGoal, is_negative::Bool)
        put!(
            program,
            getSentenceTemplete(
                program # 从模板处获取
            ).put_goal(goal, is_negative)
        )
    end
    
    "奖励目标" # TODO: 这里的所谓「奖惩/Babble」似乎不适合在一个「程序」上体现，或许更多要移动到Agent里面去？
    function praise!(program::NARSProgram, goal::NARSGoal)
        put!(
            program,
            getSentenceTemplete(
                program # 从模板处获取
            ).praise(goal)
        )
    end
    
    "惩罚目标"
    function punish!(program::NARSProgram, goal::NARSGoal) # 不强制Nothing
        put!(
            program,
            getSentenceTemplete(
                program # 从模板处获取
            ).punish(goal)
        )
    end
    
    # 感知

    function put!(program::NARSProgram, np::NARSPerception)
        put!(
            program,
            getSentenceTemplete(
                program # 从模板处获取
            ).sense(np)
        )
    end

    # 操作

    "添加无意识操作（用NARSOperation重载put!，对应PyNEI的put_unconscious_operation）" # TODO：是否可以将其和put!整合到一起？（put一个操作）
    function put!(program::NARSProgram, op::NARSOperation)
        put!(
            program,
            getSentenceTemplete(
                program # 从模板处获取
            ).babble(op) # 注意：无需判断了，只需要「输入无效」就能实现同样效果
        )
    end
    
    "添加「操作注册」：让NARS「知道」有这个操作（对应PyNEI的register_basic_operation）"
    function register!(program::NARSProgram, op::NARSOperation)
        put!(
            program,
            getSentenceTemplete(
                program # 从模板处获取
            ).register(op)
        )
    end
    
end

begin "NARSCmdline"
    
    """抽象类：所有用命令行实现的CIN
    - 使用一个子进程，运行CIN主程序
    - 现在使用asyncio库实现异步交互
    - 从asyncio启动一个主进程
    - 使用两个异步函数实现交互
    """
    abstract type NARSCmdline <: NARSProgram end
    
    # 抽象构造函数（TODO：进程结构）
    NARSCmdline(process_CIN, read_out_thread, write_in_thread) = begin
        new(process_CIN, read_out_thread, write_in_thread)
    end
    
    # 📝对引入「公共属性」并不看好
    
    "存活依据：主进程非空"
    isAlive(cmd::NARSCmdline)::Bool = 
        hasproperty(cmd, :process) && 
        isdefined(cmd, :process) && 
        !isnothing(cmd.process)
    # 先判断「有无属性」，再判断「是否定义」，最后判断「是否为空」
    # TODO：避免用符号「:process」导致「无法自动重命名」的问题
    # 进展：没能编写出类似「@soft_isnothing_property cmd.process」自动化（尝试用「hasproperty($object, property_name)」插值「自动转换成Symbol」混乱，报错不通过）
    
    "实现「启动」方法"
    function launch!(cmd::NARSCmdline)::Nothing
        # @super NARSProgram launch!(cmd)
        # TODO: 启动两个线程
        launch_CIN!(cmd)
        launch_IO!(cmd)
        # add_to_cmd!(cmd, `*volume=0`) # 这句似乎不是必须的
    end
    
    "【独有】启动具体的CIN程序"
    function launch_CIN!(::NARSCmdline, exec_cmd::String)
        
        # TODO：创建进程
        on.process = "WIP: Open Process with $exec_cmd"
    end
    
    "【独有】启动IO守护线程（相当于Python的「_launch_thread_read」与「_launch_thread_write」）"
    function launch_IO!(cmd::NARSCmdline)::Nothing
        @WIP launch_IO!(cmd::NARSCmdline)::Nothing
        nothing
    end
    
    "【独有】命令行（put!的原理）"
    function add_to_cmd!(cmd::NARSCmdline, input::String)
        add_to_cmd!(cmd, Cmd(input|>split|>Vector{String}))
    end
    
    "实际上还是要用cmd进行交互？"
    function add_to_cmd!(cmd::NARSCmdline, input::Cmd)
        "WIP: added $(input) to cmd!!" |> println
        cmd 
    end

    "留给「写线程」调用的钩子：置入语句（置入命令，相当于Python的add_input）"
    function write_in_hook(cmd::NARSCmdline, input)
        add_to_cmd!(cmd, input * "\n") # 增加换行符
    end

    "[TODO：对接线程]留给「读线程」调用的钩子：读取输出（相当于Python的read_line）"
    function read_out_hook(cmd::NARSCmdline, stdout)
        return @WIP read_out_hook(cmd::NARSCmdline, stdout)
        for line in iter(stdout.readline, b"\n")
            # 每次运行时检查自身「是否存活」，若程序已终止，则退出「结束后不断输出空字符」的死循环！
            if !isAlive(cmd)
                break
            end
            # 传递单个输出行到指定外接钩子
            use_hook(cmd, strip(line))
        end
        stdout.close() # 关闭输出流
    end
    
    "实现方法：推理循环步进"
    function cycle!(cmd::NARSCmdline, steps::Integer)
        add_to_cmd!(cmd, "$steps\n") # 增加指定步骤
    end
    
    "（API）从stdout读取输出"
    read_line(::NARSCmdline, stdout) = @abstractMethod
    
    "（API）捕捉操作名（静态）TODO：在Templete语句模板中实现？"
    catch_operation_name(::NARSCmdline, line) = @abstractMethod
    
    "（API）异步写入：从自身指令缓冲区中读取输入，送入程序的stdin中"
    async_write_lines(cmd::NARSCmdline, line) = @abstractMethod
    
    # 📌在使用super调用超类实现后，还能再派发回本类的实现中（见clear_cached_input!）
    function terminate!(cmd::NARSCmdline)::Nothing
        println("NARSCmdline terminate!")
        clear_cached_input!(cmd) # 清空而不置空（不支持nothing）
        # TODO：杀进程
        cmd.process = nothing
        @super NARSProgram terminate!(cmd) # 构造先父再子，析构先子再父
    end
    
    "【独有】缓存的命令（使用公共属性实现）"
    cached_inputs(cmd::NARSCmdline)::Vector{String} = cmd.cached_inputs
    
    "缓存的输入数量" # 注：使用前置宏无法在大纲中看到方法定义
    num_cached_input(cmd::NARSCmdline)::Integer = length(cmd.cached_inputs)
    
    "清除缓存的输入"
    function clear_cached_input!(cmd::NARSCmdline)::Vector{String}
        println("Cmd $cmd: clear_cached_input!")
        empty!(cmd.cached_inputs)
    end

end

# 导入「CIN注册」（与「具体接口定义」分离）
include("CIN_Implements.jl")
