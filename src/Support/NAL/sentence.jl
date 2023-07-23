"情态：陈述「.」、目标「!」、问题「?」"
# abstract type AbstractPunct end
# abstract type Statement <: AbstractPunct end
# abstract type Goal <: AbstractPunct end
# abstract type Question <: AbstractPunct end
#= 【20230717 23:37:104】不使用「抽象类型」标定「情态」
因：情态名称与Elements中内容重名，不便定义区分
📌解决方法：(暂时)使用Symbol区分
=#

# 【20230717 19:27:25】集成性考虑：是否要单独把这些「语法映射规则」独立出去？
const PUNCT_CHAR_DICT::Dict{Symbol, Char} = Dict(
    :judgement => '.',
    :goal => '!',
    :question => '?',
    :quest => '?',
)

"所有NAL语句的抽象基类"
struct Sentence
    punct::Symbol # 有效值参照上面Dict
    statement::AbstractStatement
end
