"""有关NARS从「具体实现」中抽象出的元素集合

在不同CIN（NARS计算机实现）中，找到一个「共通概念」，用这些「共通概念」打造不同CIN的沟通桥梁

- Perception 感知
- Operation 操作
- Sensor 感知器

注：
- 不使用Module：后期全部include到一块使用
"""

# 目标 #

"""🆕抽象出一个「NARS目标」

主要功能：记录NARS的目标名字，方便后续派发识别
"""
struct NARSGoal
    name::String
end

nameof(ng::NARSGoal) = ng.name

string(op::NARSGoal)::String = nameof(op)

repr(op::NARSGoal)::String = "<NARS Goal $(string(op))!>"

"控制在show中的显示形式"
@redefine_show_to_to_repr ng::NARSGoal

"快捷定义方式"
macro NARSGoal_str(str::String)
    :(NARSGoal($str))
end


# 操作 #

"""抽象出一个「纳思操作」

主要功能：记录其名字，并方便语法嵌入

TODO 后续可扩展：操作参数
"""
struct NARSOperation
    "操作名"
    name::String
end

nameof(op::NARSOperation) = op.name

string(op::NARSOperation)::String = nameof(op)

repr(op::NARSOperation)::String = "<NARS Operation ^$(string(op))>"

"控制在show中的显示形式"
@redefine_show_to_to_repr op::NARSOperation

"快捷定义方式"
macro NARSOperation_str(str::String)
    :(NARSOperation($str))
end


# 感知 #

"内置常量：NARS内置对象名「自我」"
const SUBJECT_SELF::String = "SELF"

"""抽象出一个「NARS感知」

主要功能：作为NARS感知的处理对象

- 记录其「主语」「表语」，且由参数**唯一确定**

TODO：类似「字符串」的静态方法（减少对象开销）
"""
struct NARSPerception
    "主语"
    subject::String
    "形容词（状态）"
    adjective::String

    "构造函数："
    NARSPerception(subject::String, adjective::String) = new(subject, adjective)
    "省略写法：默认使用「自我」做主语（单参数，不能用默认值）"
    NARSPerception(adjective::String) = new(SUBJECT_SELF, adjective)
end

string(np::NARSPerception)::String = "<{$(np.subject)} -> [$(np.adjective)]>"

repr(np::NARSPerception)::String = "<NARS Perception: {$(np.subject)} -> [$(np.adjective)]>"

"控制在show中的显示方式"
@redefine_show_to_to_repr np::NARSPerception

"使用宏快速构造NARS感知"
macro NARSPerception_str(adjective::String, subject::String)
    :(NARSPerception($subject, $adjective))
end

"无「主语」参数：自动缺省（构造「自身感知」）"
macro NARSPerception_str(adjective::String)
    :(NARSPerception($adjective)) # 注意：不能用上面的宏来简化，右边的flag用$插值会出问题
end


# 感知器 #

"""抽象出一个「NARS感知器」

主要功能：作为NARS感知的处理器，根据环境提供的参数生成相应「NARS感知」

- 主要函数：sense(参数) -> 操作集合

TODO：抽象成一个「_perceiveHook: enabled」的字典？
"""
mutable struct NARSSenser
    enabled::Bool
    perceive_hook::Union{Function,Nothing}
    
    "主构造函数"
    NARSSenser(
        enabled::Bool=true, perceive_hook::Union{Function,Nothing}=nothing
    ) = new(enabled, perceive_hook)
    
    NARSSenser(perceive_hook::Union{Function,Nothing}=nothing) = new(true, perceive_hook)
end

"直接调用：（在使能的条件下）执行相应函数钩子"
function (ns::NARSSenser)(args...; kwargs...)::Vector{NARSPerception}
    if ns.enabled && !isnothing(ns.perceive_hook)
        return ns.perceive_hook(args...; kwargs...)
    end
    return NARSPerception[] # 否则返回空数组
end

string(ns::NARSSenser)::String = "<NARS Senser -$(ns.enabled ? "×" : "-")> $(ns.perceive_hook)>"

repr(ns::NARSSenser)::String = string(ns)

"控制在show中的显示代码"
@redefine_show_to_to_repr ns::NARSSenser

