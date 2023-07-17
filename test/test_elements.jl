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
"Default Difference: " |> println
@show ds0 = SensorDifference(f) # 默认Any
@assert s.enabled # （不推荐）直接访问字段
empty!(collector)
ds0(collector, 1; a=1) # 最初会添加一次感知
@assert !isempty(collector)
last_col::Integer = length(collector)
ds0(collector, 1; a=1)
@assert last_col == length(collector) # 重复信号，长度不变
ds0(collector, 2; a=3) # 值发生变化，会再添加一次感知
@assert last_col < length(collector) # 长度发生变化
@show collector

# 测试：使用指定「基线函数」的差分感知器
"Special-Baseline Difference: " |> println
@show ds1 = SensorDifference(Tuple, f, df, ≠, false)
@assert !ds1(collector) # 没激活就调用，默认为false
ds1.enabled = true # 激活
empty!(collector) # 清空
ds1(collector, 1; a=1) # 最初会添加一次感知
@assert !isempty(collector)
ds1(collector, 1; a=1)
ds1(collector, 2; a=3) # 因为`df`评估的是「参数数量」，因此不会触发添加
ds1(collector, 1; a=1, b=2) # 再次触发添加
@show collector

# 测试：使用指定「差异函数」的差分感知器
"Special-Distinct Difference: " |> println
#= 把「差异函数」变成了「相等函数」，会产生一种「第一印象」效应
📝这种「差异效应」换成「判断在一定范围内相似」的函数，会让感知器变得不对（离群）剧烈变化敏感
- 所谓「差异函数」这时变成了「相似函数」
- 💡这样可以用于感知「稳定性」
=#
@show ds2 = SensorDifference(f, f, (==), true) # 变不等为等号
@assert enabled(ds2) && !has_baseline(ds2.filter) # baseline尚未初始化
empty!(collector)
ds2(collector, 1; a=1) # 建立「第一印象」
@assert has_baseline(ds2.filter) # 这时候内部baseline建立
last_col::Integer = length(collector)
@assert !isempty(collector) # 「第一印象」被输出
@show collector # 展示「第一印象」
ds2(collector, 1; a=2) # 重复三次输入不同的信号，因为不满足「差异条件」而没有输出
ds2(collector, 2; a=1)
ds2(collector, 2; a=2)
@assert last_col == length(collector) # 长度不变
ds2(collector, 1; a=1) # 再次输入「第一印象」
@assert last_col < length(collector) # 有所响应！
@show collector # 会发现重复了原来的感知

# 词项

@show aterm::AtomicTerm = Term(TERM_SELF)
@assert aterm |> nameof == "SELF"
@assert aterm.type == TermType"I"
@assert "$aterm" == "{SELF}"

"量化函数：参数数量总和"
qf(collector::Vector{Perception}, args...; kwargs...) = (args, kwargs) .|> length |> sum

fz::SensorFiltered = SensorFiltered(
    f, 
    FilterZScore(
            qf, # 量化函数
            z -> @show z z in -1:1 # 评估函数：「不要太偏离标准差」
    )
)
@show fz

empty!(collector)

fz(collector, 1,2; a=1)
@assert isdefined(fz.filter, :baseline)

@show fz fz.filter.baseline collector
@assert length(collector) > 0