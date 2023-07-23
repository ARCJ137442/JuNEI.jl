"""
有关NARS智能体(Agent)与CIN(Computer Implement of NARS)的通信

前身：
- Boyang Xu, *NARS-FighterPlane*
- ARCJ137442, *NARS-FighterPlane v2.i alpha*

类の概览
- CINProgram：抽象一个NARS程序
- CINCmdline：实现以命令行为形式的CIN通信接口
"""
module CIN

using ...Support
# using ..NARSElements

# 导出

export NARSType, @NARSType_str, inputType, unsafe_inputType

export CINProgram, CINCmdline, CINJuliaModule
export has_hook, use_hook, out_hook!
export isAlive, launch!, terminate!
export getNARSType, getRegister # async_read_out

export add_to_cmd!, cycle!
export cached_inputs, cache_input!, num_cached_input, cache_input!, clear_cached_input!, flush_cached_input!

begin "NARSType"
    
    # 不适合用@enum
    """
    NARSType：给出CIN的类型标识符
    - 【20230723 14:11:26】不解耦的原因：CIN四处都会用到
    """
    struct NARSType
        name::String
    end
        
    begin "转换用方法（名称，不需要字典）" # 实际上这相当于「第一行使用字符串」的表达式，但「无用到可以当注释」
        
        "NARS类型→名称"
        Base.nameof(nars_type::NARSType)::String = nars_type.name
        Base.string(nars_type::NARSType)::String = Base.nameof(nars_type)
        Base.convert(::Core.Type{String}, nars_type::NARSType) = Base.nameof(nars_type)

        "名称→NARS类型"
        Base.convert(::Core.Type{NARSType}, type_name::String) = NARSType(type_name)
        # 注：占用枚举类名，也没问题（调用时返回「ERROR: LoadError: UndefVarError: `NARSType` not defined」）
        "名称→NARS类型（直接用宏调用）"
        macro NARSType_str(type_name::String)
            :($(NARSType(type_name))) # 与其运行时报错，不如编译时就指出来
        end

        "特殊打印格式：与宏相同"
        Base.repr(nars_type::NARSType) = "NARSType\"$(Base.nameof(nars_type))\"" # 注意：不能直接插值，否则「StackOverflowError」
        @redefine_show_to_to_repr nars_type::NARSType

        "检测非空"
        function Base.isempty(nars_type::NARSType)::Bool
            isempty(nars_type.name)
        end

        "非健壮输入（合法的）NARSType"
        function unsafe_inputType(prompt::AbstractString="")::NARSType
            return prompt |> input |> NARSType
        end
        
        "健壮输入NARSType"
        function inputType(prompt::AbstractString="")::NARSType
            while true
                try
                    return prompt |> input |> NARSType
                catch
                    printstyled("Invalid Input!\n", color=:red)
                end
            end
        end
        
    end

end

begin "CINProgram" # 使用这个「代码块」将功能相近的代码封装到一起
    
    """具体与纳思通信的「程序」
    核心功能：负责与「NARS的具体计算机实现」沟通
    - 例：封装好的NARS程序包（支持命令行交互）
    """
    abstract type CINProgram end
    
    "抽象属性声明：使用外部构造方法"
    function CINProgram(
        type::NARSType,
        out_hook::Union{Function,Nothing}=nothing,
        )
        @debug "Construct: CINProgram with $out_hook, $type"
        return new(out_hook, type) # 返回所涉及类的一个实例（通用构造方法名称）
    end

    "复制一份副本（所有变量），但不启动"
    Base.copy(program::CINProgram)::CINProgram = copy(program)
    "similar类似copy"
    Base.similar(program::CINProgram)::CINProgram = copy(program)

    # 析构函数
    function Base.finalize(program::CINProgram)::Nothing
        terminate!(program)
    end
    
    # 程序相关 #
    
    "判断「是否有钩子」"
    has_hook(program::CINProgram)::Bool = !isnothing(program.out_hook)

    "（有钩子时）调用钩子（输出信息）"
    use_hook(program::CINProgram, content::String) = has_hook(program) && program.out_hook(content)
    
    "设置对外接口：函数钩子"
    function out_hook!(program::CINProgram, newHook::Union{Function,Nothing})::Union{Function,Nothing}
        program.out_hook = newHook
    end

    "重载：函数第一位，以支持do语法"
    function out_hook!(newHook::Function, program::CINProgram)::Function
        program.out_hook = newHook
    end
    
    "（API）程序是否存活（开启）"
    isAlive(program::CINProgram)::Bool = @abstractMethod # 抽象属性变为抽象方法
    
    "（API）启动程序"
    launch!(program::CINProgram)::Nothing() = @abstractMethod
    
    "终止程序"
    function terminate!(program::CINProgram)
        program.out_hook = nothing # 置空
        @debug "CINProgram terminate!"
    end
    
    # NAL相关 #

    "暴露一个「获取CIN类型」的外部接口（convert容易忘）"
    getNARSType(program::CINProgram)::NARSType = program.type
    
    """
    "通过CIN直接获得「NARS语句模板」（convert容易忘，也容易造成耦合）"
    - 【20230723 14:00:47】目的：解耦——通过「函数声明」摆脱CIN本身对Register的依赖
    - 实现参考: Register/CINRegistry.jl
    """
    function getRegister end
    
    "（API）添加输入（NAL语句字符串）：对应PyNEI的「write_line」"
    Base.put!(program::CINProgram, input::String) = @abstractMethod

    "针对「可变长参数」的多项输入" # 不强制inputs的类型
    function Base.put!(program::CINProgram, input1, input2, inputs...) # 不强制Nothing
        # 使用多个input参数，避免被派发到自身
        put!(program, (input1, input2, inputs...))
    end

    "针对「可变长参数」的多项输入" # 不强制inputs的类型
    function Base.put!(program::CINProgram, inputs::Union{Vector,Tuple}) # 不强制Nothing
        # 注意：Julia可变长参数存储在Tuple而非Vector中
        for input ∈ inputs
            put!(program, input)
        end
    end
    
    "（API）【立即？】增加NARS的工作循环：对应PyNEI的「add/update_inference_cycle」"
    cycle!(::CINProgram, steps::Integer)::Nothing = @abstractMethod
    # 【20230706 10:11:04】Program不再内置「inference_cycle_frequency」，由调用者自行决定（派发cycle!）
    
end

begin "CINCmdline"
    
    """囊括所有使用「命令行语句IO」实现的CIN
    - open一个子进程，异步运行CIN主程序
    - 通过「println(process.in, input)」向CIN输入信息
    """
    mutable struct CINCmdline <: CINProgram

        # 继承CINProgram #
        
        "存储对应CIN类型"
        type::NARSType
        
        "外接钩子"
        out_hook::Union{Function,Nothing}

        # 独有属性 #

        "程序路径"
        executable_path::String
        
        "缓存的输入"
        cached_inputs::Vector{String}
        
        "CIN进程"
        process::Base.Process

        """
        宽松的内部构造方法
        - 定义为**内部构造方法**之因：让`process`未定义，以便不用`Union{Nothing, ...}`
            - 因：但new顺序定死，没法灵活
        """
        function CINCmdline(
            type::NARSType,
            executable_path::String, 
            out_hook::Union{Function, Nothing} = nothing, 
            cached_inputs::Vector{String} = String[] # Julia动态初始化默认值（每调用就计算一次，而非Python中只计算一次）
            )
            new(
                type,
                out_hook, 
                executable_path, 
                cached_inputs #=空数组=#
            )
        end
    end

    "实现：复制一份副本（所有变量），但不启动"
    Base.copy(cmd::CINCmdline)::CINCmdline = CINCmdline(
        cmd.type,
        cmd.executable_path,
        cmd.out_hook,
        copy(cached_inputs), # 可变数组需要复制
    )
    "similar类似copy"
    Base.similar(cmd::CINCmdline)::CINCmdline = copy(cmd)
    
    # 📝Julia对引入「公共属性」并不看好
    
    "存活依据：主进程非空"
    isAlive(cmd::CINCmdline)::Bool = 
        !@soft_isnothing_property(cmd.process) && # 进程是否非空
        # !eof(cmd.process) && # 是否「文件结束」（！会阻塞主进程）
        cmd.process.exitcode != 0 && # 退出码正常吗
        process_running(cmd.process) && # 是否在运行
        !process_exited(cmd.process) # 没退出吧
    # 先判断「有无属性」，再判断「是否定义」，最后判断「是否为空」
    # TODO：避免用符号「:process」导致「无法自动重命名」的问题
    # 进展：没能编写出类似「@soft_isnothing_property cmd.process」自动化（尝试用「hasproperty($object, property_name)」插值「自动转换成Symbol」混乱，报错不通过）
    
    "实现「启动」方法（生成指令，打开具体程序）"
    function launch!(cmd::CINCmdline)
        # @super CINProgram launch!(cmd)
        # TODO：使用cmd间接启动「管不到进程」，直接启动「主进程阻塞」

        isempty(cmd.executable_path) && error("empty executable path!")

        # 输入初始指令 ？是要在cmd中启动，还是直接在命令中启动？
        startup_cmds::Tuple{Cmd,Vector{String}} = cmd.executable_path |> (cmd |> getRegister).exec_cmds

        launch_cmd::Cmd = startup_cmds[1]

        @async begin # 开始异步进行操作
            try

                # process::Base.Process = open(`cmd /c $launch_cmd`, "r+") # 打开后的进程不能直接赋值给结构体的变量？
                # cmd.process = process

                process::Base.Process = open(`cmd`, "r+") # 打开后的进程不能直接赋值给结构体的变量？
                cmd.process = process
                sleep(0.75)
                launch_cmd_str::String = replace("$launch_cmd"[2:end-1], "'" => "\"") # Cmd→String
                # 不替换「'」为「"」则引发「文件名或卷标语法不正确。」
                put!(cmd, launch_cmd_str) # Cmd转String

                @debug "Process opened with isAlive(cmd) = $(isAlive(cmd))" 

                # ！@async中无法直接打开程序

                for startup_cmd ∈ startup_cmds[2]
                    put!(cmd, startup_cmd)
                end

                sleep(0.25)

                !isAlive(cmd) && @warn "CIN命令行程序未启动：$cmd\n启动参数：$startup_cmds"
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
    function async_read_out(cmd::CINCmdline)
        line::String = "" # Julia在声明值类型后必须初始化
        while isAlive(cmd)
            try # 注意：Julia中使用@async执行时，无法直接显示与跟踪报错
                line = readline(cmd.process)
                !isempty(line) && use_hook(
                    cmd, line |> strip |> String # 确保SubString变成字符串
                ) # 非空：使用钩子
            catch e
                @error e
            end
        end
        "loop end!" |> println
    end

    # 📌在使用super调用超类实现后，还能再派发回本类的实现中（见clear_cached_input!）
    "继承：终止程序（暂未找到比较好的方案）"
    function terminate!(cmd::CINCmdline)
        @debug "CINCmdline terminate! $cmd"
        clear_cached_input!(cmd) # 清空而不置空（不支持nothing）

        # 【20230716 9:14:43】TODO：增加「是否强制」选项，用taskkill杀死主进程（java, NAR, main），默认为false
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

        # 【20230714 13:41:18】即便上面的loop end了，程序也没有真正终止
        cmd.process.exitcode = 0 # 设置标识符（无奈之举），让isAlive(cmd)=false
        # 【20230718 13:08:50】📝使用「Base.invoke」或「@invoke」实现Python的`super().方法`
        @invoke terminate!(cmd::CINProgram) # 构造先父再子，析构先子再父
    end

    "重载：直接添加至命令"
    function Base.put!(cmd::CINCmdline, input::String)
        # @async add_to_cmd!(cmd, input) # 试图用异步而非「缓存」解决「写入卡死」问题
        cache_input!(cmd, input) # 先加入缓存
        flush_cached_input!(cmd) # 再执行&清除
    end
    
    "（慎用）【独有】命令行（直接写入）"
    function add_to_cmd!(cmd::CINCmdline, input::String)
        # @info "Added: $input" # 【20230710 15:52:13】Add目前工作正常
        println(cmd.process.in, input) # 使用println输入命令
    end
    
    "实现方法：推理循环步进"
    function cycle!(cmd::CINCmdline, steps::Integer)
        inp::String = getRegister(cmd).cycle(steps) # 套模板
        !isempty(inp) && add_to_cmd!(
            cmd,
            inp,
        ) # 增加指定步骤（println自带换行符）
    end
    
    "【独有】缓存的命令"
    cached_inputs(cmd::CINCmdline)::Vector{String} = cmd.cached_inputs
    
    "缓存的输入数量" # 注：使用前置宏无法在大纲中看到方法定义
    num_cached_input(cmd::CINCmdline)::Integer = length(cmd.cached_inputs)

    "将输入缓存（不立即写入CIN）"
    cache_input!(cmd::CINCmdline, input::String) = push!(cmd.cached_inputs, input)

    "清除缓存的输入"
    clear_cached_input!(cmd::CINCmdline) = empty!(cmd.cached_inputs)

    "将所有缓存的输入全部*异步*写入CIN，并清除缓存"
    function flush_cached_input!(cmd::CINCmdline)
        for cached_input ∈ cmd.cached_inputs
            @async add_to_cmd!(cmd, cached_input)
        end
        clear_cached_input!(cmd)
    end

end

begin "CINJuliaModule"
    
    """囊括所有使用「Julia模块」实现的CIN

    一些看做「共有属性」的getter
    - modules(::CINJuliaModule)::Dict{String, Module}: 存储导入的Junars模块
        - 格式：「模块名 => 模块对象」
    """
    abstract type CINJuliaModule <: CINProgram end

    "实现：复制一份副本（所有变量），但不启动"
    Base.copy(jm::CINJuliaModule)::CINJuliaModule = CINJuliaModule(
        jm.type,
        jm.out_hook,
        jm.cached_inputs |> copy, # 可变数组需要复制
    )
    "similar类似copy"
    Base.similar(jm::CINJuliaModule)::CINJuliaModule = copy(jm)

    "（API）获取所持有的模块::Dict{String, Module}"
    modules(::CINJuliaModule)::Dict{String,Module} = @abstractMethod

    """
    检查CIN的模块导入情况
    - 返回：检查的CIN「是否正常」
    """
    function check_modules(jm::CINJuliaModule)::Bool
        # 遍历检查所有模块
        for module_name in jm.module_names
            if !haskey(modules(jm), module_name) || isnothing(modules(jm)[module_name]) # 若为空
                @debug "check_modules ==> 未载入模块`$module_name`！"
                return false
            end
        end
        return true
    end

end

# 注册对接OpenJunars的实现
include("CIN/OpenJunars.jl")

end
