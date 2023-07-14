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

@show @macroexpand @softed_isnothing_property object :property

@exceptedError error()
