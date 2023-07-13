"""有关NARS从「具体实现」中抽象出的元素集合

在不同CIN（NARS计算机实现）中，找到一个「共通概念」，用这些「共通概念」打造不同CIN的沟通桥梁

- Perception 感知
- Operation 操作
- Sensor 感知器

"""
module NARSElements

using ..Utils # 一个「.」表示当前模块下，两个「.」表示上一级模块下

import Base: nameof, isempty, getindex, string, repr, show #=
导入Base，并向Base函数中添加方法
防止调用报错「no method matching isempty(::Tuple{String})
You may have intended to import Base.isempty」
- 或「重载内置函数失败」
=#

export nameof, isempty, getindex, string, repr, show

export TermType, @TermType_str, Term, AtomicTerm
export Goal, @Goal_str
export Operation, @Operation_str, EMPTY_Operation, SUBJECT_SELF, has_parameters
export Perception, @Perception_str, collect_perception!
export Sensor


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
        TERM_TYPE_NAME_ABBREVIATION_DICT::Dict{String, TermType} = Dict(
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

    TARM_TYPE_SURROUNDING_DICT::Dict{TermType,String} = Dict(
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

    """抽象出一个「NARS感知」

    主要功能：作为NARS感知的处理对象

    - 记录其「主语」「表语」，且由参数**唯一确定**

    TODO：类似「字符串」的静态方法（减少对象开销）
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

    """抽象出一个「NARS感知器」

    主要功能：作为NARS感知的处理器，根据环境提供的参数生成相应「NARS感知」

    - 主要函数：sense(自身,收集器,其它参数) -> 向收集器里添加感知
    """
    mutable struct Sensor
        enabled::Bool
        perceive_hook::Function # 20230710 15:48:03 现不允许置空
    end

    "外部构造函数"
    Sensor(
        perceive_hook::Function,
        enabled::Bool=true, # 默认值
    ) = Sensor(enabled, perceive_hook)

    "在不检查enabled的情况下"
    function collect_perception!(sensor::Sensor, args...; kwargs...)
        sensor.perceive_hook(args...; kwargs...)
    end

    "直接调用：（在使能的条件下）执行相应函数钩子"
    function (ns::Sensor)(args...; kwargs...)
        ns.enabled && collect_perception!(ns, args...; kwargs...)
    end

    Base.string(ns::Sensor)::String = "<NARS Senser -$(ns.enabled ? "-" : "×")> $(ns.perceive_hook)>"

    Base.repr(ns::Sensor)::String = string(ns)

    "控制在show中的显示代码"
    @redefine_show_to_to_repr ns::Sensor

end

end