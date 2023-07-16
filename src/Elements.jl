"""
有关NARS从「具体实现」中抽象出的元素集合

在不同CIN（NARS计算机实现）中，找到一个「共通概念」，用这些「共通概念」打造不同CIN的沟通桥梁

- (WIP)Term 词项
    - 【20230716 21:39:11】？是否需要以此整一个「NAL孪生」，自己实现一遍NAL语句解析
- Goal 目标
- Perception 感知
- Operation 操作
- Sensor 感知器

"""
module NARSElements

using ..Utils # 一个「.」表示当前模块下，两个「.」表示上一级模块下

using Reexport # 使用reexport自动重新导出
@reexport import Base: nameof, isempty, getindex, string, repr, show, (≠) #=
导入Base，并向Base函数中添加方法
防止调用报错「no method matching isempty(::Tuple{String})
You may have intended to import Base.isempty」
- 或「重载内置函数失败」（没有export）
=#

export TermType, @TermType_str, Term, AtomicTerm

export Goal, @Goal_str

export Operation, @Operation_str, EMPTY_Operation, has_parameters

export SUBJECT_SELF, TERM_SELF
export Perception, @Perception_str
export AbstractSensor, SensorBasic, SensorDifference
export enabled, perceive_hook, collect_perception!, has_baseline


begin "一些实用代码"

    # 注意：分模块后，宏展开调用的是「宏所在模块」的变量

    """重定义show方法到repr
    
    把show方法重定义到repr上，相当于直接打印repr（无换行）
    
    例：「Base.show(io::IO, op::Goal) = print(io, repr(op))」
    """
    macro redefine_show_to_to_repr(ex)
        name::Symbol = ex.args[1]
        type::Symbol = ex.args[2]
        :(
            Base.show(io::IO, $name::$type) = print(io, repr($name))
        )
    end
    
end

# 词项(WIP) #
begin "词项"

    begin "TermType"

        """定义对NARS（原子）词项类型的枚举
        理论来源：《Non-Axiomic-Language》，《NAL》
        """
        @enum TermType begin
            TermType_BASIC # 基础
            TermType_INSTANCE # {实例}
            TermType_PROPERTY # [属性]
            TermType_COMPOUND # 复合词项（语句词项是一个特殊的复合词项，故此处暂不列出）
        end
        
        "缩写字典：使用TermType'B'取类型"
        const TERM_TYPE_NAME_ABBREVIATION_DICT::Dict{String, TermType} = Dict(
            "B" => TermType_BASIC,
            "I" => TermType_INSTANCE,
            "P" => TermType_PROPERTY,
            "C" => TermType_COMPOUND,
        )

        "用宏定义缩写"
        macro TermType_str(name::String)
            :($(TERM_TYPE_NAME_ABBREVIATION_DICT[name]))
        end
    end

    "所有NAL词项的基类"
    abstract type Term end

    """原子词项：Atomic Term
    「The basic form of a term is a word, a string of letters in a
    finite alphabet.」——《NAL》"""
    struct AtomicTerm <: Term
        name::String
        type::TermType

        # AtomicTerm(name::String, type::TermType=TermType_BASIC) = new(
        #     name,
        #     type,
        # )
    end

    const TARM_TYPE_SURROUNDING_DICT::Dict{TermType,String} = Dict(
        TermType_BASIC => "",
        TermType_INSTANCE => "{}",
        TermType_PROPERTY => "[]",
        TermType_COMPOUND => "",
    )

    """纯字符串⇒原子词项（自动转换类型）
    例：AtomicTerm("{SELF}") = 例：AtomicTerm("SELF", TermType_INSTANCE)
    """
    function AtomicTerm(raw::String)
        t::Tuple{Function,Function} = (first, last)
        # 遍历判断
        for (type,surrounding) in TARM_TYPE_SURROUNDING_DICT
            if !isempty(surrounding) && (surrounding .|> t) == (raw .|> t) # 头尾相等
                return AtomicTerm(raw[2:end-1], type)
            end
        end
        return AtomicTerm(raw, TermType_BASIC) # 默认为基础词项类型
    end

    "获取词项名"
    Base.nameof(term::Term)::String = @abstractMethod
    Base.nameof(aterm::AtomicTerm)::String = aterm.name

    "获取词项字符串&插值入字符串" # 注意重载Base.string
    function Base.string(aterm::AtomicTerm)::String
        surrounding::String = TARM_TYPE_SURROUNDING_DICT[aterm.type]
        if !isempty(surrounding)
            return surrounding[1] * nameof(aterm) * surrounding[end] # 使用字符串拼接
        end
        nameof(aterm)
    end

    "格式化对象输出"
    Base.repr(term::Term)::String = "<NARS Term $(string(term))>"

    # "控制在show中的显示形式"
    @redefine_show_to_to_repr term::Term

    macro Term_str(content::String)
        :(Term($content))
    end

    "String -> Term"
    function Term(raw::String)::Term
        # 暂且返回「原子词项」
        return AtomicTerm(raw)
    end
end

begin "目标"

    """抽象出一个「NARS目标」

    主要功能：记录NARS的目标名字，方便后续派发识别
    """
    struct Goal
        name::String
    end

    "获取目标名"
    Base.nameof(ng::Goal) = ng.name

    "插值入字符串"
    Base.string(op::Goal)::String = nameof(op)

    "show表达式"
    Base.repr(op::Goal)::String = "<NARS Goal $(string(op))!>"

    "控制在show中的显示形式"
    @redefine_show_to_to_repr ng::Goal

    "快捷定义方式"
    macro Goal_str(str::String)
        :(Goal($str))
    end
    
end



begin "操作"

    raw"""抽象出一个「纳思操作」

    主要功能：记录其名字，并方便语法嵌入
    - 附加功能：记录操作执行的参数（词项组）

    实用举例：
    - Operation("pick", ("{SELF}", "{t002}"))
        - 源自OpenNARS「EXE: $0.10;0.00;0.08$ ^pick([{SELF}, {t002}])=null」

    TODO：对其中的「"{SELF}"」，是否需要把它变成结构化的「NARS词项」？
    """
    struct Operation
        "操作名"
        name::String

        "操作参数" # 使用「Varar{类型}」表示「任意长度的指定类型」（包括空元组Tuple{}）
        parameters::Tuple{Vararg{String}}

        """默认构造方法：接受一个名称与一个元组
        - *优先匹配*（避免下面的构造方法递归）
        - 避免：
            - 传入SubString报错：String方法
            - 空字串参数：filter方法
        """
        Operation(name::AbstractString, parameters::Tuple{Vararg{String}}) = new(String(name), filter(!isempty, parameters))
        # filter过滤掉「空字符串」，使空字符串无效化

        "通用构造方法：名称+任意数量元组"
        Operation(name::AbstractString, parameters...) = Operation(name, parameters)
    end

    """空字串操作⇔空操作
    注意：不是「有一个空字符串的操作」
        - ❌<NARS Operation ^operation_EXE()>
    """ # 也可使用「Operation""」构建
    EMPTY_Operation::Operation = Operation("")

    "检测「是否有参数」"
    has_parameters(op::Operation) = !isempty(op.parameters)

    Base.isempty(op::Operation) = (op == EMPTY_Operation)

    "返回名称"
    Base.nameof(op::Operation) = op.name

    "传递「索引读取」到「参数集」"
    Base.getindex(op::Operation, i) = Base.getindex(op.parameters, i)
    # 必须使用Base

    "字符串转化&插值"
    Base.string(op::Operation)::String = "$(nameof(op))$(
        has_parameters(op) ? "($(join(op.parameters,",")))" : ""
    )" # Tuple自带括号，故不用加括号

    "格式化显示：名称+参数"
    Base.repr(op::Operation)::String = "<NARS Operation ^$(string(op))>"

    "控制在show中的显示形式"
    @redefine_show_to_to_repr op::Operation

    "快捷定义方式"
    macro Operation_str(str::String)
        :(Operation($str))
    end

end

begin "感知"

    # 感知语句 #

    "内置常量：NARS内置对象名「自我」"
    const SUBJECT_SELF::String = "SELF"
    
    "表示「自我」的对象"
    const TERM_SELF::String = "{$SUBJECT_SELF}"

    """抽象出一个「NARS感知」

    主要功能：作为NARS感知的处理对象

    - 记录其「主语」「表语」，且由参数**唯一确定**

    TODO：类似「字符串」的静态存储方法（减少对象开销）
    """
    struct Perception

        "主语"
        subject::String

        "形容词（状态）"
        adjective::String

        "构造函数：主语&形容词"
        Perception(subject::String, adjective::String) = new(subject, adjective)

        "省略写法：默认使用「自我」做主语（单参数，不能用默认值）"
        Perception(adjective::String) = new(SUBJECT_SELF, adjective)
    end

    "插值入字符串"
    Base.string(np::Perception)::String = "<{$(np.subject)} -> [$(np.adjective)]>"

    "show表达式"
    Base.repr(np::Perception)::String = "<NARS Perception: {$(np.subject)} -> [$(np.adjective)]>"

    "控制在show中的显示方式"
    @redefine_show_to_to_repr np::Perception

    "使用宏快速构造NARS感知"
    macro Perception_str(adjective::String, subject::String)
        :(Perception($subject, $adjective))
    end

    "无「主语」参数：自动缺省（构造「自身感知」）"
    macro Perception_str(adjective::String)
        :(Perception($adjective)) # 注意：不能用上面的宏来简化，右边的flag用$插值会出问题
    end

    # 感知器 #

    begin "抽象感知器"

        """抽象出一个「NARS感知器」

        主要功能：作为NARS感知的处理器，根据环境提供的参数生成相应「NARS感知」
        - 主要函数：被调用 -> 向收集器里添加感知
            - 调用约定：`感知器对象(收集器, 其它参数)`
        - 默认约定的「共有字段」（在未重载前使用的函数，推荐用函数而非字段）
            - enabled：是否使能
            - perceive_hook：外调函数
        """
        abstract type AbstractSensor end

        "（默认：开关状态字段）属性「是否使能」"
        enabled(s::AbstractSensor) = s.enabled

        """
        （默认：字段perceive_hook）属性「外调函数」
        - 约定：`perceive_hook(收集器, 其它附加参数)::Union{Vector{Perception}, Nothing}`
            - 参数：第一个*位置参数*必定是「收集器」对象
            - 返回值：Perception（若需自动添加）/nothing（无需自动添加）
            - 🔗见下面`collect_perception!`对钩子的调用
        """
        perceive_hook(s::AbstractSensor) = s.perceive_hook

        """
        （默认）在不检查enabled的情况下：直接执行「外调函数」，
        - 将「收集器」也传递到外调函数，以供参考
            - 后续可以让外调函数「根据已有感知做出对策」
        - 把「外调函数」返回的Perception数据（若非空）添加到收集器
        - 【20230716 23:12:54】💭不把Sensor作为参数传递的理由
            - 「从其它参数中返回感知对象」暂不需要「感知器本身」参与
            - 📌范式：若需要在「输出感知」层面进行功能增加（如「累积统计」功能），
                更推荐「扩展新类」而非「将外调函数复杂化」
        """
        function collect_perception!(
            sensor::AbstractSensor, 
            collector::Vector{Perception}, 
            targets...; targets_kw...
            )
            perceptions::Union{Vector{Perception}, Nothing} = (perceive_hook(sensor))(collector, targets...; targets_kw...)
            !isnothing(perceptions) && push!(
                collector,
                perceptions...
            )
        end

        "直接调用：（在使能的条件下）执行感知（返回值不使用）"
        function (s::AbstractSensor)(
            collector::Vector{Perception}, # 收集器
            targets...; # 位置参数
            targets_kw... # 关键字参数
            ) # 返回值不重要
            enabled(s) && collect_perception!(s, collector, targets...; targets_kw...)
        end

        "字符串显示"
        Base.string(s::AbstractSensor)::String = "<NARS $(typeof(s)) -$(enabled(s) ? "-" : "×")> $(perceive_hook(s))>"

        "插值显示=字符串"
        Base.repr(s::AbstractSensor)::String = string(s)

        "同步在show中的显示代码"
        @redefine_show_to_to_repr s::AbstractSensor

    end

    begin "具体感知器实现"

        """
        基础感知器：一个最简单的感知器
        - 功能：在被调用时，直接返回其「外调函数」返回的感知对象
        - 一切都遵循其父抽象类的**默认处理方式**
        """
        mutable struct SensorBasic <: AbstractSensor
            enabled::Bool
            perceive_hook::Function # 20230710 15:48:03 现不允许置空

            "构造方法"
            SensorBasic(
                perceive_hook::Function,
                enabled::Bool=true, # 默认值
            ) = new(enabled, perceive_hook)
        end

        """
        差分感知器：只对「信号的变化」敏感
        - 作为「只对变化敏感」的感知器，其**只在信号发生变化**时才输出
        - 输出机制：生成「当前基线」⇒基线比对⇒差分输出
            1. 对输入的感知→记忆函数生成「当前记忆」
            2. 与「感知基线」作比对
                - 若同：不输出
                - 若异：输出至收集器，并划定新基线
        - 「基线函数」约定：`baseline_hook(收集器, 其它附加参数)::Any`
            - 参数类型：同「外调函数」
            - 返回类型：任意（可比）值
        - 启发来源：[2021年会报告](https://www.bilibili.com/video/BV1ND4y1w7M5?t=1299.6&p=9)
        
        > 感觉系统不是对所有信号敏感，而是对信号的变化敏感。
        > 感觉信号没有逻辑意义的真值，但有信号意义的真值。
        """
        mutable struct SensorDifference{BaselineType} <: AbstractSensor
            enabled::Bool
            perceive_hook::Function

            baseline_hook::Function # 目标对象→基线参考（产生用于对比的值）

            "差异函数：两个「基线对象」→「是否有差异」"
            distinct_function::Function # (::BaselineType, ::BaselineType)::Bool

            "所谓「感知基线」"
            baseline::BaselineType # 【20230716 23:16:49】放最后是为了使用「未定义」状态

            "构造方法"
            function SensorDifference{BaselineType}(
                perceive_hook::Function, # 只有在「基线」更新时起效
                baseline_hook::Function=perceive_hook, # 默认和「外调钩子」是一样的
                distinct_function::Function=(≠), # 默认为「不等号」
                enabled::Bool=true,
            ) where BaselineType
                new{BaselineType}(
                    enabled,
                    perceive_hook,
                    baseline_hook,
                    distinct_function,
                    # nothing # 使用「未定义」形式规避「类型转换」问题（Union不是首选）
                )
            end

            "语法糖：不指定类型⇒默认Any"
            SensorDifference(a...;k...) = SensorDifference{Any}(a...;k...)
        end

        "（新）是否有「基线」：检测「先前是否已经感知过」"
        has_baseline(s::SensorDifference) = isdefined(s, :baseline)

        "（重载）字符串显示"
        Base.string(s::SensorDifference)::String = "<NARS $(typeof(s)) | $(s.baseline_hook) -$(enabled(s) ? "-" : "×")> $(s.perceive_hook)>"

        """
        （重载）差分感知：在不检查enabled的情况下，
        1. 先执行`baseline_hook`，返回「作为基线的参考对象」
        2. 把`baseline_hook`返回的「参考对象」与已有的「基线对象」作比对
            - 若同：不对收集器作处理
            - 若异：
                1. 运行`perceive_hook`，真正生成`Perception`对象并将此添加至收集器
                2. 将「参考对象」作为新的「基线对象」
        """
        function collect_perception!(
            sensor::SensorDifference{BaselineType}, 
            collector::Vector{Perception}, 
            targets...; targets_kw...
            ) where BaselineType
            # 构造「参考对象」
            reference::BaselineType = sensor.baseline_hook(collector, targets...; targets_kw...)
            # 比对：初次or有差别
            if !has_baseline(sensor) || sensor.distinct_function(sensor.baseline, reference) # 使用自定义的「差异函数」
                # 【20230716 21:19:53】在已知有`perceive_hook`字段时，无需再调用函数获取
                perceptions::Union{Vector{Perception}, Nothing} = sensor.perceive_hook(collector, targets...; targets_kw...)
                !isnothing(perceptions) && push!(
                    collector,
                    perceptions...
                )
                sensor.baseline = reference
            end
        end

    end
end

end