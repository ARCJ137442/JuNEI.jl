module Utils

using Reexport # 使用reexport自动重新导出

begin "宏辅助"

    @reexport import Base: (+), (*)
    export @reverse_dict_content, @soft_isnothing_property, @exceptedError, @recursive
    
    "基本代码拼接"
    (e1::Expr) + (e2::Expr) = quote
        $e1
        $e2
    end
    
    "代码复制（TODO：多层begin-end嵌套问题）"
    (ex::Expr) * (k::Integer) = sum([ex for _ in 1:k])
    
    (k::Integer) * (ex::Expr) = ex * k
    
    "反转字典"
    macro reverse_dict_content(name::Symbol)
        :(
            v => k
            for (k,v) in $name
        )
    end

    "函数重复嵌套调用"
    macro recursive(f, x, n::Integer)
        s = "$x"
        for _ in 1:n
            s = "$f($s)" # 重复嵌套
        end
        esc(Meta.parse(s)) # 使用esc避免立即解析
    end

    "软判断「是否空值」（避免各种报错）：有无属性→有无定义→是否为空"
    macro soft_isnothing_property(object::Symbol, property_name::Symbol)
        # 📝使用「esc」避免在使用「$」插值时的「符号立即解析」
        # 📝要想让「:符号」参数在被插值时还是解析成「:符号」，就使用「:(Symbol($("$property_name")))」
        eo1, ep1 = object, :(Symbol($("$property_name"))) # 初始参数
        :(
            !hasproperty($eo1, $ep1) || # 是否有
            !isdefined($eo1, $ep1) || # 定义了吗
            isnothing(getproperty($eo1, $ep1)) # 是否为空
        ) |> esc # 整体使用esc，使之在返回后才被解析（不使用返回前的变量作用域）
    end

    "用于`@soft_isnothing_property 对象 :属性名`的形式"
    macro soft_isnothing_property(object::Symbol, property_name::QuoteNode)
        # 「作为一个符号导入的符号」property_name是一行「输出一个符号的Quote代码」如「:(:property))」
        # 对「:属性名」的「QuoteNode」，提取其中value的Symbol
        #= 📝对「在宏中重用其它宏」的方法总结
            1. 使用`:(@宏 $(参数))`的形式，避免「边定义边展开」出「未定义」错
            2. 对「待展开符号」进行esc处理，避免在表达式返回前解析（作用域递交）
        =#
        :(@soft_isnothing_property $object $(property_name.value)) |> esc
    end

    "用于`@soft_isnothing_property 对象.属性名`的形式"
    macro soft_isnothing_property(expr::Expr)
        #= 📝dump「对象.属性名」的示例：
            Expr
            head: Symbol .
            args: Array{Any}((2,))
                1: Symbol cmd
                2: QuoteNode
                value: Symbol process
        =#
        :(@soft_isnothing_property $(expr.args[1]) $(expr.args[2].value)) |> esc
    end

    "【用于调试】判断「期望出错」（仿官方库show语法）"
    macro exceptedError(exs...)
        Expr(:block, [ # 生成一个block，并使用列表推导式自动填充args
            quote
                local e = nothing
                try
                    $(esc(ex))
                catch e
                    @error "Excepted error! $e"
                end
                # 不能用条件语句，否则局部作用域访问不到ex；也不能去掉这里的双重$引用
                isnothing(e) && "Error: No error expected in code $($(esc(ex)))!" |> error
                !isnothing(e)
            end
            for ex in exs
        ]...) # 别忘展开
    end

end

begin "统计学辅助：动态更新算法"
    
    # 【20230717 15:02:55】不打算「导入统计学库并添加方法」：避免引入额外依赖
    # @reexport import Statistics: var, std
    @reexport import Base: getindex, setindex!

    export CMS
    export update!, var, std, z_score

    """
    CMS: Confidence, Mean and mean of Square
    一个结构体，只用三个值，存储**可动态更新**的均值、标准差
    - 避免「巨量空间消耗」：使用「动态更新」方法
    - 避免「数值存储溢出」：使用「信度」而非「数据量」
    """
    mutable struct CMS{ValueType}

        # 信度 c = n/(n+1)
        c::Number # 【20230717 16:18:40】这里必须要反映原先的「n∈正整数」

        # 均值 = 1/n ∑xᵢ
        m::ValueType

        # 方均值 = 1/n ∑xᵢ²
        s::ValueType
    end

    "构造方法：c缺省⇒0代替"
    function CMS{ValueType}(m::ValueType, s::ValueType) where ValueType
        CMS{ValueType}(0.0, m, s)
    end

    "无参数：默认使用zero函数"
    CMS{ValueType}() where ValueType = CMS{ValueType}(zero(ValueType), zero(ValueType))

    "无泛型：默认泛型为Number"
    CMS(a...; k...) = CMS{Number}(a...; k...)

    "默认中的默认"
    CMS() = CMS{Number}()

    """
    更新均值（使用广播以支持向量化）
    - 公式：m_new = c m_old + (1-c) new
    - 直接使用「c = n/(n+1)」将「旧均值」「新数据」线性组合
    """
    function update_mean(old_mean, old_c, new)
        old_mean .* old_c .+ new .* (1 - old_c)
    end

    "更新方均值"
    function update_square_mean(old_smean, old_c, new)
        update_mean(
            old_smean,
            old_c,
            new .^ 2,
        )
    end

    "总更新"
    function update!(cms::CMS{ValueType}, new::ValueType)::CMS{ValueType} where ValueType
        # 先更新两个均值，再更新c
        cms.m = update_mean(cms.m, cms.c, new)
        cms.s = update_square_mean(cms.s, cms.c, new)
        cms.c = 1/(2-cms.c) # 相当于「n→n+1」

        return cms
    end

    "语法糖：直接调用⇒更新"
    function (cms::CMS{ValueType})(new::ValueType) where ValueType
        update!(cms, new)
    end

    """
    语法糖：使用「数组索引」处理n值
    - 公式：n = c/(1-c)
    - ⚠此举尝试获得精确的值
    """
    getindex(cms::CMS)::Unsigned = (cms.c / (1 - cms.c)) |> round |> Unsigned

    "无Keys：设置n值（从n逆向计算c）" # 【20230717 16:58:54】日后再考虑引进「k值」代表「每个新数据的权重」
    function setindex!(cms::CMS, n::Number) # , keys...
        cms.c = n / (n+1)
    end

    """
    根据公式计算方差（均差方）
    - 公式：D = 1/n ∑(xᵢ-̄x)² = 1/n ∑xᵢ² - ̄x
    - 实质：「各统计值与均值之差的平方」的均值
    """
    var(cms::CMS; corrected::Bool=false) = corrected ? (_var(cms) * cms.c / (2cms.c-1)) : _var(cms)
    
    """
    内部计算用的（有偏）方差（均差方）
    - 公式：D = s - m²
        - 口诀：「平方的均值-均值的平方」
    - 默认采用「有偏估计」：`corrected::Bool=false`
        - 因为这个CMS是要**不断随新数据而修正**的，不存在固定的「总体」一说
        - 在这个「累计修正」的环境下，样本不断丰富，没有「总体」这件事
    - 有偏估计：直接除以样本总量（这里无需修正因子）
        - 在「样本=总体」的情况下，「有无偏」其实无所谓
            - 所谓「有无偏」实际上是要在「用样本估计总体」的情境下使用
    - 无偏估计：直接除以信度即乘以「修正因子」n/(n-1)=(2c-1)/c
        - 用这个「修正因子」替换分母「n→(n-1)」
    
    📌坑：有「关键字参数」的方法定义要放在前
    - 无关键字参数会导致「UndefKeywordError: keyword argument `correct` not assigned」
    """
    _var(cms::CMS) = cms.s .- cms.m .^ 2 # 使用广播运算以支持「向量化」

    """
    根据统计值计算标准差（使用广播以支持向量化）
    - 公式：σ=√D
        - 样本=总体→有偏估计
    - 默认「有偏估计」（不要「-1」）
    """
    std(cms::CMS; corrected::Bool=false) = var(cms; corrected=corrected) .|> sqrt
    # std(cms::CMS) = cms |> var |> sqrt # 【20230717 12:40:42】Method definition overwritten, incremental compilation may be fatally broken for this module

    """
    根据均值、标准差计算另一个值的「Z-分数」（无量纲量）
    - 公式：z(v) = (v-x) / σ
    - 默认「有偏估计」（不要「-1」）
    """
    function z_score(cms::CMS{ValueType}, other::ValueType; corrected::Bool=false) where ValueType
        # 针对「单例情况」：即便标准差为0，z分数也为零（避免「除零错误」）
        diff::ValueType = (other .- cms.m)
        return diff==0 ? diff : diff ./ std(cms; corrected=corrected)
    end

end

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

begin "========一些OOP宏========"

    export @redefine_show_to_to_repr, @abstractMethod, @WIP, @super

    """重定义show方法到repr
    
    把show方法重定义到repr上，相当于直接打印repr（无换行）
    
    例：「Base.show(io::IO, op::Goal) = print(io, repr(op))」
    """
    macro redefine_show_to_to_repr(ex)
        name::Symbol = ex.args[1]
        type::Symbol = ex.args[2]
        :(
            Base.show(io::IO, $(esc(name))::$(esc(type))) = print(io, repr($(esc(name))))
        )
    end

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
    """
        @super 超类 函数(参数表达式)
    
    用于复现类似Python中的「super()」语法（"一组符号" 直接使用Tuple{各组符号的Type}）
    - 等价于Python的`super().函数(参数表达式)`
    
    """
    macro super(super_class::Expr, f_expr::Expr)
        # @show super_class f_expr
        :(
            invoke(
                $(esc(f_expr.args[1])), # 第一个被调用函数名字
                $(esc(super_class)), # 第二个超类类型
                $((f_expr.args[2:end] .|> esc)...) # 第三个被调用函数的参数集
            ) # 📝「$((args .|> esc)...」先使用esc获得局部变量，再使用「...」展开参数集
        )
    end

    """承载超类的方法：默认第一个参数是需要super的参数"""
    macro super(super_class::Symbol, f_expr::Expr)
        # 📌方法：「@show @macroexpand」两个方法反复「修改-比对」直到完美
        # 📝使用esc避免表达式被立即解析
        :(
            invoke(
                $(esc(f_expr.args[1])), # 第一个被调用函数名字
                Tuple{$(esc(super_class))}, # 第二个超类类型
                $((f_expr.args[2:end] .|> esc)...) # 第三个被调用函数的参数集
            ) # 📝「$((args .|> esc)...」先使用esc获得局部变量，再使用「...」展开参数集
        )
    end

end

begin "其它辅助函数"

    export input, @input_str
    export <|

    "复现Python的「input」函数"
    function input(prompt::String="")::String
        print(prompt)
        readline()
    end

    """
        input"提示词"

    input的Julian高级表达
    """
    macro input_str(prompt::String)
        :(input($prompt))
    end
    
end

end