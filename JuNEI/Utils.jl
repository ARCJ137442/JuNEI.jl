import Base: (+), (*)

"基本代码拼接"
(e1::Expr) + (e2::Expr) = quote
    $e1
    $e2
end

"代码复制（TODO：多层begin-end嵌套问题）"
(ex::Expr) * (k::Integer) = sum([ex for _ in 1:k])

(k::Integer) * (ex::Expr) = ex * k

#=
    macro C() # 注：这样也可以实现「代码拼接」，但效率不高
        (@macroexpand @A) + (@macroexpand @B)
    end
    弃用：宏代码拼接（quote嵌套无法eval到，各类参数递归报错）

    "代码拼接"
    macro macrosplice(codes...)
        # 一元情况
        if length(codes) == 1
            return quote
                $(codes[1])
            end
        # 二元情况
        elseif length(codes) == 2
            return quote
                $(codes[1])
                $(codes[2])
            end
        end
        # 多元：递归
        return quote
            $(codes[1])
            @show @macroexpand @macrosplice($(codes[2:end]...))
        end
    end

    q1 = quote
        a = 1
    end

    q2 = quote
        b = 2
    end

    @macrosplice quote
        a = 1
    end quote
        b = 2
    end quote
        c = 3
    end

    @macrosplice quote
        a += 1
    end quote
        b += 1
    end quote
        c += 1
    end

    @show a b c
=#
"========一些OOP宏========"

"""重定义show方法到repr

把show方法重定义到repr上，相当于直接打印repr（无换行）

例：「Base.show(io::IO, op::NARSGoal) = print(io, repr(op))」
"""
macro redefine_show_to_to_repr(ex)
    name::Symbol = ex.args[1]
    type::Symbol = ex.args[2]
    :(
        Base.show(io::IO, $name::$type) = print(io, repr($name))
    )
end

# 注册抽象方法

"注册抽象方法：不给访问，报错"
macro abstractMethod()
    :(error("Abstract Function!"))
end

"有参数：一行函数直接插入报错"
macro abstractMethod(sig)
    :($(esc(sig)) = @abstractMethod)
end

"指示「正在开发中」"
macro WIP(contents...)
    str = "WIP: $(length(contents) == 1 ? contents[1] : contents)"
    :($str |> println) # 必须在外面先定义str再插进去，否则会被误认为是「Main.contents」
end

# 调用超类方法
# 📝使用invoke替代Python中super()的作用
# 参考：https://discourse.julialang.org/t/invoke-different-method-for-callable-struct-how-to-emulate-pythons-super/57869
# 📌在使用invoke强制派发到超类实现后，在「超类实现」的调用里，还能再派发回本类的实现中（见clear_cached_input!）
"""用于复现类似Python中的「super()」语法（"一组符号" 直接使用Tuple{各组符号的Type}）"""
macro super(super_class::Expr, f_expr::Expr)
    @show super_class f_expr
    :(
        invoke(
            $(f_expr.args[1]), # 第一个被调用函数名字
            $(super_class), # 第二个超类类型
            $((f_expr.args[2:end] .|> esc)...) # 第三个被调用函数的参数集
        ) # 📝「$((args .|> esc)...」先使用esc获得局部变量，再使用「...」展开参数集
    )
end

"""承载超类的方法：默认第一个参数是需要super的参数"""
macro super(super_class::Symbol, f_expr::Expr)
    # :(@super Tuple{$super_class} $f_expr) # 无法解决递归调用问题：「Main.cmd」导致的「UndefVarError: `cmd` not defined」
    # 不需要过多的esc包装，只需要新建一个符号，在这个符号下正常进行插值即可
    # 📌方法：「@show @macroexpand」两个方法反复「修改-比对」直到完美
    :(
        invoke(
            $(f_expr.args[1]), # 第一个被调用函数名字
            Tuple{$super_class}, # 第二个超类类型
            $((f_expr.args[2:end] .|> esc)...) # 第三个被调用函数的参数集
        ) # 📝「$((args .|> esc)...」先使用esc获得局部变量，再使用「...」展开参数集
    )
end
