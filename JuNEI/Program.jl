"""有关NARS智能体(NARSAgent)与CIN(Computer Implement of NARS)的通信

前身：
- Boyang Xu, *NARS-FighterPlane*
- ARCJ137442, *NARS-FighterPlane v2.i alpha*

类の概览
- NARSType: 注册已有的CIN类型
- NARSProgram：抽象一个CIN通信接口
"""

"""NARSType：注册已有CIN类型
注册在目前接口中可用的CIN类型
- OpenNARS(Java)
- ONA(C/C++)
- Python(Python)
- 【未来还可更多】
"""
@enum NARSType begin
    OpenNARS = 1 # Julia枚举的值不能是字符串……
    ONA = 2
    Python = 3
end

"构建一个字典，存储从NARSType到字符串名字的映射"
TYPE_NAME_DICT::Dict{NARSType, String} = Dict{NARSType, String}(
    OpenNARS => "OpenNARS",
    ONA => "ONA",
    Python => "Python",
)

"构造反向字典"
NAME_TYPE_DICT::Dict{String, NARSType} = Dict{String, NARSType}(
    v => k
    for (k,v) in TYPE_NAME_DICT
)

"NARS类型→名称"
nameof(nars_type::NARSType)::String = TYPE_NAME_DICT[nars_type]

"名称→NARS类型"
NARSType(type_name::String)::NARSType = NAME_TYPE_DICT[type_name]
# 注：占用枚举类名，也没问题（调用时返回「ERROR: LoadError: UndefVarError: `NARSType` not defined」）

# 注册抽象方法 #

"注册抽象方法：不给访问，报错"
macro abstractMethod()
    :(error("Abstract Function!"))
end

"有参数：一行函数直接插入报错"
macro abstractMethod(sig)
    :($(esc(sig)) = @abstractMethod)
end


"""具体与纳思通信的「程序」
核心功能：负责与「NARS的具体计算机实现」沟通
- 例：封装好的NARS程序包（支持命令行交互）
"""
abstract type NARSProgram end

# 抽象属性的注册→构造函数的参数
NARSProgram(out_hook::Function, cached_inputs::Vector{String}) = begin
    return new(out_hook, cached_inputs) # 返回所涉及类的一个实例（通用构造函数名称）
end

# 析构函数
function finalize(program::NARSProgram)::Nothing
    terminate!(program)
end

# 程序相关 #

"程序是否存活（开启）"
@abstractMethod isAlive(program::NARSProgram)::Bool # 抽象属性变为抽象方法

"启动程序"
@abstractMethod launch!(program::NARSProgram)::Nothing()

"终止程序"
function terminate!(program::NARSProgram)::Nothing
    clear_cached_input!(program)
    program.out_hook = nothing # 置空
    empty!(program.cached_inputs) # 清空而不置空（不支持nothing）
    println("NARSProgram terminate!")
end

"缓存的输入数量"
@abstractMethod num_cached_input(program::NARSProgram)::Integer

"清除缓存的输入"
@abstractMethod clear_cached_input!(program::NARSProgram)::Nothing

# NAL相关 #

"添加输入（NAL语句）：对应PyNEI的「add_input」"
@abstractMethod put!(program::NARSProgram, input::String)::Nothing

"增加NARS的工作循环：对应PyNEI的「add/update_inference_cycle」"
@abstractMethod cycle!(program::NARSProgram, ::Integer)::Nothing
"同上：无参数则是更新"
@abstractMethod cycle!(program::NARSProgram)::Nothing

# 目标
# TODO：抽象一个NARSGoal，然后利用多重派发整合到put!里面？

"添加目标"
@abstractMethod put_goal!(program::NARSProgram, goal_name::String, is_negative::Bool)::Nothing

"奖励目标" # TODO: 这里的所谓「奖惩/Babble」似乎不适合在一个「程序」上体现，或许更多要移动到Agent里面去？
@abstractMethod praise_goal!(program::NARSProgram, goal_name::String)::Nothing

"惩罚目标"
@abstractMethod punish_goal!(program::NARSProgram, goal_name::String)::Nothing

"是否可以Babble"
@abstractMethod enable_babble(program::NARSProgram)::Bool

"添加无意识操作" # TODO：是否可以将其和put!整合到一起？（put一个操作）
@abstractMethod put_unconscious_operation!(program::NARSProgram)::Nothing

"添加「操作注册」：让NARS「知道」有这个操作"
@abstractMethod register_basic_operation!(program::NARSProgram)::Nothing

"""抽象类：所有用命令行实现的CIN
- 使用一个子进程，运行CIN主程序
- 现在使用asyncio库实现异步交互
- 从asyncio启动一个主进程
- 使用两个异步函数实现交互
"""
abstract type NARSCmdline <: NARSProgram end


# "一组符号" 直接使用Tuple{各组符号的Type}
macro super(super_class::Expr, f_expr::Expr)
    @show super_class f_expr
    :(
        invoke(
            $(f_expr.args[1]), # 第一个被调用函数名字
            $(super_class), # 第二个超类类型
            $((f_expr.args[2:end] .|> esc)...) # 第三个被调用函数的参数集
        ) # 📝「$((args .|> esc)...」先使用esc获得局部变量，再使用「...」展开参数集
    )
end

# "承载超类的方法：默认第一个参数是需要super的参数"
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

# 📝使用invoke替代Python中super()的作用
# 参考：https://discourse.julialang.org/t/invoke-different-method-for-callable-struct-how-to-emulate-pythons-super/57869
# 📌在使用invoke强制派发到超类实现后，在「超类实现」的调用里，还能再派发回本类的实现中（见clear_cached_input!）
function terminate!(cmd::NARSCmdline)::Nothing
    # invoke(terminate!, Tuple{NARSProgram}, cmd) # 替代super的作用
    @super NARSProgram terminate!(cmd)
    println("NARSCmdline terminate!")
end

function clear_cached_input!(cmd::NARSCmdline)::Nothing
    println("CMD $cmd: clear_cached_input!")
end

"""Java版实现：OpenNARS
"""
mutable struct NARSProgram_OpenNARS <: NARSCmdline
    out_hook::Union{Function, Nothing}
    cached_inputs::Vector{String}

    NARSProgram_OpenNARS(
        out_hook::Union{Function, Nothing} = nothing,
        cached_inputs::Vector{String} = String[] # 空数组
    ) = new(out_hook, cached_inputs) # 宽松的构造函数
end

function cycle!(on::NARSProgram_OpenNARS)
    println("WIP")
end