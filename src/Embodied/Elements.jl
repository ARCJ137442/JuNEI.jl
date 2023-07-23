"""
有关NARS从「具体实现」中抽象出的元素集合

在不同CIN（NARS计算机实现）中，找到一个「共通概念」，用这些「共通概念」打造不同CIN的沟通桥梁

- Goal 目标
- Perception 感知
- Operation 操作
- Sensor 感知器

"""
module NARSElements

using ...Support # .当前模块⇒..Embodied⇒...JuNEI⇒「JuNEI.Support」

#= 📝向Base已有的函数中添加方法的渠道
1. 导入Base，并向Base函数中添加方法
2. 在所有「方法声明」处注明`Base.方法名(参数集)`
    - 此方法不用导入Base模块

作用之一：防止调用报错「no method matching isempty(::Tuple{String})
                     You may have intended to import Base.isempty」
- 或「重载内置函数失败」（没有export）
=#

export TermType, @TermType_str, Term, AtomicTerm

export Goal, @Goal_str

export Operation, @Operation_str, EMPTY_Operation, has_parameters

export Perception, @Perception_str

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

begin "感知"

    # 感知语句 #

    """抽象出一个「NARS感知」

    主要功能：作为NARS感知的处理对象

    - 记录其「主语」「表语」，且由参数**唯一确定**

    TODO：
    - 类似「字符串」的静态存储方法（减少对象开销）
    - 将其中的String变成Term（真正的「词项」）
    """
    struct Perception

        "主语"
        subject::String

        "形容词（属性，对应NAL的`[property]`）"
        property::String

    end

    "外部构造方法 简略写法：默认使用「自我」做主语（单参数，不能用默认值）"
    Perception(property::String) = Perception(SUBJECT_SELF_STR, property)

    "插值入字符串"
    Base.string(np::Perception)::String = "<{$(np.subject)} -> [$(np.property)]>"

    "show表达式"
    Base.repr(np::Perception)::String = "<NARS Perception: {$(np.subject)} -> [$(np.property)]>"

    "控制在show中的显示方式"
    @redefine_show_to_to_repr np::Perception

    "使用宏快速构造NARS感知"
    macro Perception_str(property::String, subject::String)
        :(Perception($subject, $property))
    end

    "无「主语」参数：自动缺省（构造「自身感知」）"
    macro Perception_str(property::String)
        :(Perception($property)) # 注意：不能用上面的宏来简化，右边的flag用$插值会出问题
    end

    # 感知器 #
    include("Elements/sensors.jl")

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

        """
        默认构造方法：接受一个名称与一个元组
        - *优先匹配*（避免下面的构造方法递归）
        - 为何是内部构造方法？避免：
            - 传入SubString报错：String方法
            - 空字串参数：filter方法（预处理）
        """
        Operation(name::Union{AbstractString,Symbol}, parameters::Tuple{Vararg{String}}) = new(
            String(name), 
            filter(!isempty, parameters) # filter过滤掉「空字符串」，使空字符串无效化
        )
    end

    "通用（外部）构造方法：名称+任意数量元组"
    Operation(name::Union{AbstractString,Symbol}, parameters::Vararg{String}) = Operation(name, parameters)

    "自动转换"

    "快捷定义方式"
    macro Operation_str(str::String)
        :(Operation($str))
    end

    """
    空字串操作⇔空操作
    - 注意：不是「有一个空字符串的操作」
        - ❌<NARS Operation ^operation_EXE()>
        - 【20230721 17:51:57】？实际上更多是直接用宏构造？
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

end

end
