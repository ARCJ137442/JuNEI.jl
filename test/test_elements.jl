push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI.NARSElements

"================Test for Elements================" |> println

# using JuNEI.NARSElements

@assert Operation"left" == Operation("left") # 使用字符串宏快速构造基础操作

@assert Goal"right" == Goal("right") # 使用字符串宏快速构造基础操作

@assert Perception"good" == Perception("good") # 静态类型直接比较相等✅

@assert Perception"left"ball == Perception("ball", "left")

f(args...; kwargs...) = [
    Perception("$args", "args"),
    [
        Perception("$k","$v")
        for (k , v) in kwargs
    ]...
]

@show s = Sensor(false, f)
@assert (Sensor(f).enabled)
# @assert isnothing(Sensor().perceive_hook) # 【20230713 23:09:18】不允许置空
s.enabled = true # 动态测试：改变开关状态
@assert s.enabled

@show s(1,2,3;a=1,b=2)

@show aterm::AtomicTerm = Term(TERM_SELF)
@assert aterm |> nameof == "SELF"
@assert aterm.type == TermType"I"
@assert "$aterm" == "{SELF}"


using JuNEI.CIN