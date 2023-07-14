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

using Reexport

using ..Utils
using ..NARSElements

# 导入注册表的「数据结构」
include("CIN/templates.jl")
@reexport using .Templates # 重新导出，但也可「按需索取」只using CIN.Templates

# 导入
import Base: isempty, copy, similar, finalize, put!, isvalid

# 导出
export isempty, copy, similar, finalize, put!, isvalid

export CINProgram, CINCmdline
export has_hook, use_hook, out_hook!
export isAlive, launch!, terminate!
export getNARSType, getRegister # async_read_out

export add_to_cmd!, cycle!
export cache_input!, num_cached_input, cache_input!, clear_cached_input!, flush_cached_input!

export @CINRegister_str # ?可以移动到templates里？


begin "因为Utils引用问题迁移过来的宏"

    """承载超类的方法：默认第一个参数是需要super的参数"""
    macro super(super_class::Symbol, f_expr::Expr)
        # :(@super Tuple{$super_class} $f_expr) # 无法解决递归调用问题：「Main.cmd」导致的「UndefVarError: `cmd` not defined」
        # 不需要过多的esc包装，只需要新建一个符号，在这个符号下正常进行插值即可
        # 📌方法：「@show @macroexpand」两个方法反复「修改-比对」直到完美
        :(
            invoke(
                $(f_expr.args[1]), # 第一个被调用函数名字
                Tuple{$super_class}, # 第二个超类类型
                $((f_expr.args[2:end] .|> esc)...) # 第三个被调用函数的参数集
            ) # 📝「$((args .|> esc)...」先使用esc获得局部变量，再使用「...」展开参数集
        )
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
        return new(out_hook, type) # 返回所涉及类的一个实例（通用构造函数名称）
    end

    "复制一份副本（所有变量），但不启动"
    copy(program::CINProgram)::CINProgram = copy(program)
    "similar类似copy"
    similar(program::CINProgram)::CINProgram = copy(program)

    # 析构函数
    function finalize(program::CINProgram)::Nothing
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

    "通过CIN直接获得「NARS语句模板」（convert容易忘）"
    getRegister(program::CINProgram)::CINRegister = convert(CINRegister, program) # 通过convert实现
    
    "（API）添加输入（NAL语句字符串）：对应PyNEI的「write_line」"
    put!(program::CINProgram, input::String) = @abstractMethod

    "针对「可变长参数」的多项输入" # 不强制inputs的类型
    function put!(program::CINProgram, input1, input2, inputs...) # 不强制Nothing
        # 使用多个input参数，避免被派发到自身
        put!(program, (input1, input2, inputs...))
    end

    "针对「可变长参数」的多项输入" # 不强制inputs的类型
    function put!(program::CINProgram, inputs::Union{Vector,Tuple}) # 不强制Nothing
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

        "宽松的构造函数（但new顺序定死，没法灵活）"
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
    copy(cmd::CINCmdline)::CINCmdline = CINCmdline(
        cmd.type,
        cmd.executable_path,
        cmd.out_hook,
        copy(cached_inputs), # 可变数组需要复制
    )
    "similar类似copy"
    similar(cmd::CINCmdline)::CINCmdline = copy(cmd)
    
    # 📝Julia对引入「公共属性」并不看好
    
    "存活依据：主进程非空"
    isAlive(cmd::CINCmdline)::Bool = 
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
    function launch!(cmd::CINCmdline)
        # @super CINProgram launch!(cmd)
        # TODO：使用cmd间接启动「管不到进程」，直接启动「主进程阻塞」

        isempty(cmd.executable_path) && error("empty executable path!")

        # 输入初始指令 ？是要在cmd中启动，还是直接在命令中启动？
        startup_cmds::Tuple{Cmd,Vector{String}} = cmd.executable_path |> (cmd |> CINRegister).exec_cmds

        launch_cmd::Cmd = startup_cmds[1]

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
    function async_read_out(cmd::CINCmdline)
        line::String = "" # Julia在声明值类型后必须初始化
        try # 注意：Julia中使用@async执行时，无法直接显示与跟踪报错
            while isAlive(cmd)
                line = readline(cmd.process)
                !isempty(line) && use_hook(
                    cmd, line |> strip |> String # 确保SubString变成字符串
                ) # 非空：使用钩子
            end
        catch e
            @error e
        end
        "loop end!" |> println
    end

    # 📌在使用super调用超类实现后，还能再派发回本类的实现中（见clear_cached_input!）
    "继承：终止程序（暂未找到比较好的方案）"
    function terminate!(cmd::CINCmdline)
        @debug "CINCmdline terminate!"
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

        # 【20230714 13:41:18】即便上面的loop end了，程序也没有真正终止
        cmd.process.exitcode = 0 # 设置标识符（无奈之举），让isAlive(cmd)=false
        @super CINProgram terminate!(cmd) # 构造先父再子，析构先子再父
        @show cmd # 测试
    end

    "重载：直接添加至命令"
    function put!(cmd::CINCmdline, input::String)
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
        add_to_cmd!(cmd, "$steps") # 增加指定步骤（println自带换行符）
    end
    
    "【独有】缓存的命令（使用公共属性实现）"
    cached_inputs(cmd::CINCmdline)::Vector{String} = cmd.cached_inputs
    
    "缓存的输入数量" # 注：使用前置宏无法在大纲中看到方法定义
    num_cached_input(cmd::CINCmdline)::Integer = length(cmd.cached_inputs)

    "将输入缓存（不立即写入CIN）"
    cache_input!(cmd::CINCmdline, input::String) = push!(cmd.cached_inputs, input)

    "清除缓存的输入"
    function clear_cached_input!(cmd::CINCmdline)::Vector{String}
        empty!(cmd.cached_inputs)
    end
    
    "将所有缓存的输入全部*异步*写入CIN，并清除缓存"
    function flush_cached_input!(cmd::CINCmdline)
        for cached_input ∈ cmd.cached_inputs
            @async add_to_cmd!(cmd, cached_input)
        end
        clear_cached_input!(cmd)
    end

end

# 「具体CIN注册」交给下面的jl：抽象接口与具体注册分离
CIN_REGISTER_DICT::Dict = include("CIN/register.jl")
#= 功能：定义CIN注册字典，存储与「具体CIN实现」的所有信息
- CIN_REGISTER_DICT：NARSType→CINRegister
注：使用include，相当于返回其文件中的所有代码
- 故可以在该文件中返回一个Dict，自然相当于把此Dict赋值给变量CIN_REGISTER_DICT
- 从而便于管理变量名（无需分散在两个文件中）
=#

#= 注：不把以下代码放到templates.jl中，是因为：
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

    "Program→Type：复现PyNEI中CINProgram的「type」属性"
    function Base.convert(::Core.Type{NARSType}, program::CINProgram)::NARSType
        return program.type
    end

    "Type→Program类" # 尽可能用Julia原装方法
    function Base.convert(::Core.Type{Core.Type}, nars_type::NARSType)::Core.Type
        CIN_REGISTER_DICT[nars_type].program_type
    end
    
    "Type→Program：复现PyNEI中的CINProgram.fromType函数（重载外部构造方法）"
    function CINProgram(nars_type::NARSType, args...; kwargs...)::CINProgram
        # 获得构造方法
        type_program = Base.convert(Core.Type, nars_type) # 「Core.Type{CINProgram}」会过于精确而报错「Cannot `convert` an object of type Type{CINProgram_OpenNARS} to an object of type Type{CINProgram}」
        # 调用构造方法
        type_program(nars_type, args...; kwargs...) # 目前第一个参数是NARSType
    end

    "Program→Type→Register（复现Python中各种「获取模板」的功能）" # 尽可能用Julia原装方法
    function Base.convert(::Core.Type{CINRegister}, program::CINProgram)::CINRegister
        CIN_REGISTER_DICT[convert(NARSType, program)]
    end

    "派发Program做构造方法"
    function CINRegister(program::CINProgram)
        Base.convert(CINRegister, program)
    end
end

end