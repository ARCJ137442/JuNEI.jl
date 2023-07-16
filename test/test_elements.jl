push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI.NARSElements

"================Test for Elements================" |> println

@assert Operation"left" == Operation("left") # 使用字符串宏快速构造基础操作

@assert Goal"right" == Goal("right") # 使用字符串宏快速构造基础操作

@assert Perception"good" == Perception("good") # 静态类型直接比较相等✅

@assert Perception"left"ball == Perception("ball", "left")

# 感知器

f(collector::Vector{Perception}, args...; kwargs...) = [
    Perception("$args", "args")
    [
        Perception("$k","$v")
        for (k , v) in kwargs
    ]...
]

df(collector::Vector{Perception}, args...; kwargs...) = (args, kwargs) .|> length

collector::Vector{Perception} = Perception[]

# 测试：指定函数的基础感知器
@show s = SensorBasic(f, false)
@assert SensorBasic(f) |> enabled # 默认激活状态
# @assert isnothing(SensorBasic().perceive_hook) # 【20230713 23:09:18】不允许置空
s.enabled = true # 动态测试：改变开关状态
@assert s.enabled
@show s(collector, 1,2,3;a=1,b=2)
@assert !isempty(collector) # 会添加几个感知对象

# 测试：从Basic「直接升级」的差分感知器
@show ds0 = SensorDifference(f)
@assert s.enabled # （不推荐）直接访问字段
empty!(collector)
ds0(collector, 1; a=1) # 最初会添加一次感知
@assert !isempty(collector)
last_col::Integer = length(collector)
ds0(collector, 1; a=1)
@assert last_col == length(collector) # 重复信号，长度不变
ds0(collector, 2; a=3) # 值发生变化，会再添加一次感知
@assert last_col ≠ length(collector) # 长度发生变化
@show collector

# 测试：使用指定「基线函数」的差分感知器
@show ds = SensorDifference(f, df, false)
@assert !ds(collector) # 没激活就调用，默认为false
ds.enabled = true # 激活
empty!(collector) # 清空
ds(collector, 1; a=1) # 最初会添加一次感知
@assert !isempty(collector)
ds(collector, 1; a=1)
ds(collector, 2; a=3) # 因为`df`评估的是「参数数量」，因此不会触发添加
ds(collector, 1; a=1, b=2) # 再次触发添加
@show collector

# 词项

@show aterm::AtomicTerm = Term(TERM_SELF)
@assert aterm |> nameof == "SELF"
@assert aterm.type == TermType"I"
@assert "$aterm" == "{SELF}"


using JuNEI.CIN