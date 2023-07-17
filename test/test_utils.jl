push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI.Utils

"================Test for Utils================" |> println

# 代码拼接
quote
    a = 1
end + quote
    b = 2
end + quote
    c = 3
end |> eval # 分别定义 a,b,c = 1,2,3
5 * quote # 加五次c
    c += 1
end |> eval

@assert a==1 && b==2 && c==8

object = Dict()

@show @macroexpand @soft_isnothing_property object :property # 本来就没有属性property
@assert @soft_isnothing_property object :property # 本来就没有属性property
@assert !@soft_isnothing_property(object.slots) # Dict有属性slots

@exceptedError @abstractMethod

f(x) = 2x # 递归嵌套
@show @macroexpand @recursive(f, 1, 10)
@assert @recursive(f, 1, 10) == 1024

@macroexpand input"input: "

# 动态更新统计量

c = CMS{Tuple}(
    (0,0),
    (0,0)
)

# 添加
for i in 1:10
    c((i,i+1))
end
@show c

c[] = 1 # 重置「总样本数」为1
@assert c.c == 0.5 # 相当于c=0.5
c((0,0))
@assert c[] == 2 # 增加一个样本，总样本数→2
@show c

c[] = 0 # 信度为零，样本作废
(0,0) |> c # 覆盖样本
(4,-4) |> c
@assert c[] == 2 && c.m == (2,-2) && c.s == (8,8) && std(c) == (2,2)

dump(c)
@show c.m std(c) z_score(c, (-1,1))
@assert z_score(c, (-1,1)) == (-1.5,1.5)
