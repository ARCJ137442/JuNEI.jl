"""有关NARS智能体(NARSAgent)与CIN(Computer Implement of NARS)的通信

前身：
- Boyang Xu, *NARS-FighterPlane*
- ARCJ137442, *NARS-FighterPlane v2.i alpha*

类の概览
- NARSProgram：抽象一个NARS程序
- NARSCmdline：实现以命令行为形式的CIN通信接口
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
    function NARSProgram(
        type::NARSType,
        out_hook::Union{Function,Nothing}=nothing,
        inference_cycle_frequency::Integer=1
        )
        @debug "Construct: NARSProgram with $out_hook, $type"
        return new(out_hook, type, inference_cycle_frequency) # 返回所涉及类的一个实例（通用构造函数名称）
    end

    # 析构函数
    function finalize(program::NARSProgram)::Nothing
        terminate!(program)
    end
    
    # 程序相关 #
    
    "判断「是否有钩子」"
    has_hook(program::NARSProgram)::Bool = !isnothing(program.out_hook)

    "（有钩子时）调用钩子（输出信息）"
    use_hook(program::NARSProgram, content::String) = has_hook(program) && program.out_hook(content)
    
    "设置对外接口：函数钩子"
    function out_hook!(program::NARSProgram, newHook::Union{Function,Nothing})::Union{Function,Nothing}
        program.out_hook = newHook
    end
    
    "（API）程序是否存活（开启）"
    isAlive(program::NARSProgram)::Bool = @abstractMethod # 抽象属性变为抽象方法
    
    "（API）启动程序"
    launch!(program::NARSProgram)::Nothing() = @abstractMethod
    
    "终止程序"
    function terminate!(program::NARSProgram)
        program.out_hook = nothing # 置空
        @debug "NARSProgram terminate!"
    end
    
    # NAL相关 #

    "暴露一个「获取CIN类型」的外部接口（convert容易忘）"
    getNARSType(program::NARSProgram)::NARSType = program.type

    "通过CIN直接获得「NARS语句模板」（convert容易忘）"
    function getRegister(program::NARSProgram)::CINRegister
        convert(CINRegister, program) # 通过convert实现
    end
    
    "（API）添加输入（NAL语句字符串）：对应PyNEI的「write_line」"
    put!(program::NARSProgram, input::String) = @abstractMethod

    "针对「可变长参数」的多项输入" # 不强制inputs的类型
    function put!(program::NARSProgram, input1, input2, inputs...) # 不强制Nothing
        # 使用多个input参数，避免被派发到自身
        put!(program, [input1,input2,inputs...])
    end

    "针对「可变长参数」的多项输入" # 不强制inputs的类型
    function put!(program::NARSProgram, inputs::Vector) # 不强制Nothing
        # 使用多个input参数，避免被派发到自身
        for input ∈ inputs
            put!(program, input)
        end
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
            getRegister(
                program # 从模板处获取
            ).put_goal(goal, is_negative)
        )
    end
    
    "奖励目标" # TODO: 这里的所谓「奖惩/Babble」似乎不适合在一个「程序」上体现，或许更多要移动到Agent里面去？
    function praise!(program::NARSProgram, goal::NARSGoal)
        put!(
            program,
            getRegister(
                program # 从模板处获取
            ).praise(goal)
        )
    end
    
    "惩罚目标"
    function punish!(program::NARSProgram, goal::NARSGoal) # 不强制Nothing
        put!(
            program,
            getRegister(
                program # 从模板处获取
            ).punish(goal)
        )
    end
    
    # 感知

    function put!(program::NARSProgram, np::NARSPerception)
        put!(
            program,
            getRegister(
                program # 从模板处获取
            ).sense(np)
        )
    end

    # 操作

    "添加无意识操作（用NARSOperation重载put!，对应PyNEI的put_unconscious_operation）" # TODO：是否可以将其和put!整合到一起？（put一个操作）
    function put!(program::NARSProgram, op::NARSOperation)
        put!(
            program,
            getRegister(
                program # 从模板处获取
            ).babble(op) # 注意：无需判断了，只需要「输入无效」就能实现同样效果
        )
    end
    
    "添加「操作注册」：让NARS「知道」有这个操作（对应PyNEI的register_basic_operation）"
    function register!(program::NARSProgram, op::NARSOperation)
        put!(
            program,
            getRegister(
                program # 从模板处获取
            ).register(op)
        )
    end
    
end

begin "NARSCmdline"
    
    """囊括所有使用「命令行语句IO」实现的CIN
    - open一个子进程，异步运行CIN主程序
    - 通过「println(process.in, input)」向CIN输入信息
    """
    mutable struct NARSCmdline <: NARSProgram

        # 继承NARSProgram #
        
        "存储对应CIN类型"
        type::NARSType
        
        "外接钩子"
        out_hook::Union{Function,Nothing}
        inference_cycle_frequency::Integer

        # 独有属性 #

        "程序路径"
        executable_path::String
        
        "缓存的输入"
        cached_inputs::Vector{String}
        
        "CIN进程"
        process::Base.Process

        "宽松的构造函数（但new顺序定死，没法灵活）"
        function NARSCmdline(
            type::NARSType,
            executable_path::String, 
            out_hook::Union{Function, Nothing} = nothing, 
            inference_cycle_frequency::Integer = 1, 
            cached_inputs::Vector{String} = String[] # Julia动态初始化默认值（每调用就计算一次，而非Python中只计算一次）
            )
            new(
                type,
                out_hook, 
                inference_cycle_frequency, 
                executable_path, 
                cached_inputs #=空数组=#
            )
        end

    end
    
    # 📝对引入「公共属性」并不看好
    
    "存活依据：主进程非空"
    isAlive(cmd::NARSCmdline)::Bool = 
        hasproperty(cmd, :process) && # 是否有
        isdefined(cmd, :process) && # 定义了吗
        !isnothing(cmd.process) && # 是否为空
        !eof(cmd.process) && # 是否「文件结束」
        cmd.process.exitcode != 0 && # 退出码正常吗
        process_running(cmd.process) && # 是否在运行
        !process_exited(cmd.process) # 没退出吧
    # 先判断「有无属性」，再判断「是否定义」，最后判断「是否为空」
    # TODO：避免用符号「:process」导致「无法自动重命名」的问题
    # 进展：没能编写出类似「@soft_isnothing_property cmd.process」自动化（尝试用「hasproperty($object, property_name)」插值「自动转换成Symbol」混乱，报错不通过）
    
    "实现「启动」方法（生成指令，打开具体程序）"
    function launch!(cmd::NARSCmdline)
        # @super NARSProgram launch!(cmd)
        # TODO：使用cmd间接启动「管不到进程」，直接启动「主进程阻塞」

        isempty(cmd.executable_path) && error("empty executable path!")

        # 输入初始指令 ？是要在cmd中启动，还是直接在命令中启动？
        startup_cmds::Tuple{Cmd,Vector{String}} = cmd.executable_path |> (cmd |> CINRegister).exec_cmds

        launch_cmd::Cmd = startup_cmds[1]
        @show launch_cmd

        @async begin # 开始异步进行操作
            try

                # process::Base.Process = open(`cmd /c $launch_cmd`, "r+") # 打开后的进程不能直接赋值给结构体的变量？
                # cmd.process = process

                process::Base.Process = open(`cmd`, "r+") # 打开后的进程不能直接赋值给结构体的变量？
                cmd.process = process
                sleep(1)
                launch_cmd_str::String = replace("$(startup_cmds[1])"[2:end-1], "'" => "\"")
                # 不替换「'」为「"」则引发「文件名或卷标语法不正确。」
                put!(cmd, launch_cmd_str) # Cmd转String

                @debug "Process opened with isAlive(cmd) = $(isAlive(cmd))" 

                # ！@async中无法直接打开程序

                for startup_cmd ∈ startup_cmds[2]
                    put!(cmd, startup_cmd)
                end
            catch e
                @error e
            end
        end

        @async async_read_out(cmd) # 开启异步读取

        sleep(1) # 测试

        @debug "Program launched with pid=$(getpid(cmd.process))"
        
        return isAlive(cmd) # 返回程序是否存活（是否启动成功）
    end
    
    "从stdout读取输出"
    function async_read_out(cmd::NARSCmdline)
        try # 注意：Julia中使用@async执行时，无法直接显示与跟踪报错
            @debug async_read_out
            line::String = "" # Julia在声明值类型后必须初始化
            while isAlive(cmd)
                line = readline(cmd.process)
                !isempty(line) && use_hook(
                    cmd, line |> strip |> String # 确保SubString变成字符串
                ) # 非空：使用钩子
            end
        catch e
            @error e
        end
        @debug "loop end!"
    end

    # 📌在使用super调用超类实现后，还能再派发回本类的实现中（见clear_cached_input!）
    "继承：终止程序（暂未找到比较好的方案）"
    function terminate!(cmd::NARSCmdline)
        @debug "NARSCmdline terminate!"
        clear_cached_input!(cmd) # 清空而不置空（不支持nothing）

        # @async kill(cmd.process) # kill似乎没法终止进程
        # @async close(cmd.process) # （无async）close会导致主进程阻塞
        # try
        #     pid::Integer = getpid(cmd.process)
        #     `taskkill -f -im java.exe` |> run
        #     `taskkill -f -im NAR.exe` |> run
        #     `taskkill -f -im main.exe` |> run
        #     `taskkill -f -pid $pid` |> run # 无奈之举（但也没法杀死进程）
        # catch e
        #     @error e
        # end # 若使用「taskkill」杀死直接open的进程，会导致主进程阻塞

        cmd.process.exitcode = 0 # 设置标识符（无奈之举），让isAlive(cmd)=false
        @super NARSProgram terminate!(cmd) # 构造先父再子，析构先子再父
        @show cmd
    end

    "重载：直接添加至命令"
    function put!(cmd::NARSCmdline, input::String)
        # @async add_to_cmd!(cmd, input) # 试图用异步而非「缓存」解决「写入卡死」问题
        cache_input!(cmd, input) # 先加入缓存
        flush_cached_input!(cmd) # 再执行&清除
    end
    
    "（慎用）【独有】命令行（直接写入）"
    function add_to_cmd!(cmd::NARSCmdline, input::String)
        @info "Added: $input"
        println(cmd.process.in, input) # 使用println输入命令
    end
    
    "实现方法：推理循环步进"
    function cycle!(cmd::NARSCmdline, steps::Integer)
        add_to_cmd!(cmd, "$steps") # 增加指定步骤（println自带换行符）
    end
    
    "【独有】缓存的命令（使用公共属性实现）"
    cached_inputs(cmd::NARSCmdline)::Vector{String} = cmd.cached_inputs
    
    "缓存的输入数量" # 注：使用前置宏无法在大纲中看到方法定义
    num_cached_input(cmd::NARSCmdline)::Integer = length(cmd.cached_inputs)

    "将输入缓存（不立即写入CIN）"
    cache_input!(cmd::NARSCmdline, input::String) = push!(cmd.cached_inputs, input)

    "清除缓存的输入"
    function clear_cached_input!(cmd::NARSCmdline)::Vector{String}
        empty!(cmd.cached_inputs)
    end
    
    "将所有缓存的输入全部*异步*写入CIN，并清除缓存"
    function flush_cached_input!(cmd::NARSCmdline)
        for cached_input ∈ cmd.cached_inputs
            @async add_to_cmd!(cmd, cached_input)
        end
        clear_cached_input!(cmd)
    end

end

# 「具体CIN注册」交给下面的jl：抽象接口与具体注册分离
CIN_REGISTER_DICT::Dict = include("CIN_Register.jl")
#= 功能：定义CIN注册字典，存储与「具体CIN实现」的所有信息
- CIN_REGISTER_DICT：NARSType→CINRegister
注：使用include，相当于返回其文件中的所有代码
- 故可以在该文件中返回一个Dict，自然相当于把此Dict赋值给变量CIN_REGISTER_DICT
- 从而便于管理变量名（无需分散在两个文件中）
=#

#= 注：不把以下代码放到Templetes.jl中，是因为：
- Program要用到NARSType
- 以下代码要等Register注册
- Register要等Program类声明
因此不能放在一个文件中
=#
begin "注册后的一些方法（依赖注册表）"

    "检验NARSType的有效性：是否已被注册"
    isvalid(nars_type::NARSType)::Bool = nars_type ∈ keys(CIN_REGISTER_DICT) # 访问字典键值信息，用方法而不用属性（否则报错：#undef的「access to undefined reference」）

    "Type→Register（依赖字典）"
    function Base.convert(::Core.Type{CINRegister}, type::NARSType)::CINRegister
        CIN_REGISTER_DICT[type]
    end

    "名称→Type→Register（依赖字典）"
    function Base.convert(::Core.Type{CINRegister}, type_name::String)::CINRegister
        CIN_REGISTER_DICT[NARSType(type_name)]
    end

    "名称→NAL语句模板（直接用宏调用）（依赖字典）"
    macro CINRegister_str(type_name::String)
        :($(Base.convert(CINRegister, type_name))) # 与其运行时报错，不如编译时就指出来
    end # TODO：自动化「用宏生成宏？」

    "Program→Type：复现PyNEI中NARSProgram的「type」属性"
    function Base.convert(::Core.Type{NARSType}, program::NARSProgram)::NARSType
        return program.type
    end

    "Type→Program类" # 尽可能用Julia原装方法
    function Base.convert(::Core.Type{Core.Type}, nars_type::NARSType)::Core.Type
        CIN_REGISTER_DICT[nars_type].program_type
    end
    
    "Type→Program：复现PyNEI中的NARSProgram.fromType函数（重载外部构造方法）"
    function NARSProgram(nars_type::NARSType, args...; kwargs...)::NARSProgram
        # 获得构造方法
        type_program = Base.convert(Core.Type, nars_type) # 「Core.Type{NARSProgram}」会过于精确而报错「Cannot `convert` an object of type Type{NARSProgram_OpenNARS} to an object of type Type{NARSProgram}」
        # 调用构造方法
        type_program(nars_type, args...; kwargs...) # 目前第一个参数是NARSType
    end

    "Program→Type→Register（复现Python中各种「获取模板」的功能）" # 尽可能用Julia原装方法
    function Base.convert(::Core.Type{CINRegister}, program::NARSProgram)::CINRegister
        CIN_REGISTER_DICT[convert(NARSType, program)]
    end

    "派发Program做构造方法"
    function CINRegister(program::NARSProgram)
        Base.convert(CINRegister, program)
    end
end
