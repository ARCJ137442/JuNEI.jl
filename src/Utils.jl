module Utils

using Reexport # 使用reexport自动重新导出

begin "宏辅助"

    export @reverse_dict_content, @soft_isnothing_property, @exceptedError, @recursive
    
    """
    基本代码拼接
    - 📌Julia中使用「Base.名字」、带`function`关键字的运算符重载，形式为`function Base.:运算符名(参数...)`
    - 【20230721 15:59:48】优化：有相同头的可以自动合并args

    ## 📝Julia中Expr的特殊head by ChatGPT
    
    在 Julia 中，`Expr` 是表示表达式的数据类型，它的 `head` 字段可以包含不同的特殊符号。特殊符号用于表示不同类型的表达式，以下是一些常见的特殊符号：
    
    1. `:call`：表示函数调用。
        - 例如，`f(x)` 可以表示为 `Expr(:call, :f, :x)`。
    2. `:ref`：表示变量引用。
        - 例如，`x` 可以表示为 `Expr(:ref, :x)`。
    3. `:block`：表示代码块。
        - 例如，`begin x = 1; y = 2; end` 可以表示为 `Expr(:block, :(x = 1), :(y = 2))`。
    4. `:if`：表示条件语句。
        - 例如，`if condition A else B end` 可以表示为 `Expr(:if, :condition, :A, :B)`。
    5. `:while`：表示循环语句。
        - 例如，`while condition body end` 可以表示为 `Expr(:while, :condition, :body)`。
    6. `:for`：表示迭代语句。
        - 例如，`for i in collection body end` 可以表示为 `Expr(:for, :(i in collection), :body)`。
    
    这只是一些常见的特殊符号示例，实际上，Julia 中的 `Expr` 类型的 `head` 可以是任何合法的 Julia 表达式。
    
    通过了解不同特殊符号在 `Expr` 中的用法，你可以更好地理解 Julia 中的表达式和语法结构。
    """
    function Base.:+(e1::Expr, e2::Expr)
        # 代码块特殊合并args
        if e1.head == e2.head == :block
            return Expr(
                e1.head, # 头：采用相等二者的其中一个即可
                e1.args...,
                e2.args...
            ) # 📌不能使用esc，会报错「syntax: invalid syntax (escape (block (line 22 」
        end
        # 默认就block quote起来（记得esc）
        return quote
            $e1
            $e2
        end # 不能用esc，原因同上
    end
    
    "代码复制（TODO：多层begin-end嵌套问题）"
    Base.:(*)(ex::Expr, k::Integer) = sum([ex for _ in 1:k])
    
    Base.:(*)(k::Integer, ex::Expr) = ex * k
    
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
        #= 📝对「在宏中重用其它宏」「宏内嵌入宏」的方法总结
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
    
    export CMS
    export update!, var, std, z_score

    """
    「均值更新器」CMS: Confidence, Mean and mean of Square
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
    Base.getindex(cms::CMS)::Unsigned = (cms.c / (1 - cms.c)) |> round |> Unsigned

    "无Keys：设置n值（从n逆向计算c）" # 【20230717 16:58:54】日后再考虑引进「k值」代表「每个新数据的权重」
    function Base.setindex!(cms::CMS, n::Number) # , keys...
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
        @debug "zscore"
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

    export @redefine_show_to_to_repr, @abstractMethod, @WIP, 
           @super, @wrap_link_in, @generate_gset_link

    """
    重定义show方法到repr
    
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

    """
    TODO：把「只有1|2个字符串参数的结构体」自动添加对应的「字符串宏」以方便输入
    """
    # macro auto_str_macro(type::Symbol)
    #     quote
    #         macro $(type)_str(s::String)
    #             :($(type)(s)) # WIP, 很可能会报错
    #         end
    #     end |> esc
    # end


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
    
    【20230718 13:09:51】现可直接使用`@invoke 函数(参数::超类类型)`表示
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

    """
    通过一个宏，自动给（先前已实现且应用的）一个结构增加一个「嵌入对象」的链接

    - 不干扰*原结构*的应用方式
    - 支持对「嵌入对象」的访问与管理

    【20230720 23:29:29】目前实现：
    - 追加一个「嵌入对象」属性到原结构中（实现为「最后的属性定义」）
    - 追加定义两个方法，用于读写原结构的「嵌入对象」（在下一个宏实现）
    - 目前实现痛点：
        - 只能在**无内部构造方法定义**时使用原装构造方法，方可为不可变类型设置「嵌入对象」
        - 无法很好处理「原结构的文档字符串」（block对象无法@doc）⇒拆分实现
    """
    macro wrap_link_in(link_prop_def::Expr, struct_def::Expr)
        # 表达式头「struct」
        struct_head::Symbol = struct_def.head
        @assert struct_head==:struct "Expression '$struct_head' ≠ ':struct'!" # 断言
    
        # 表达式参数「是否可变::Bool，结构体名::Symbol，结构体代码(Expr block)」
        _, struct_name::Symbol, code::Expr = struct_def.args
        
        push!(
            code.args, 
            link_prop_def, # 增加属性定义到最后（确保是最后一个变量，而不影响原来的构造函数）
            :($struct_name(args...; kwargs...) = new(args...; kwargs...)) # 黑入一个内部构造方法，避免被原来的内部构造方法限制
        )
    
        # 📌生成区块Expr(:block, 各代码块)也不是不行，但为了兼容「文档字符串」暴露struct，只能拆分
        struct_def |> esc # 📌不使用esc则「立即解析」const报错「expected assignment after "const" around [...]」
    end
    
    """
    （独立成宏）追加定义两个方法，用于读写原结构的「嵌入对象」
    """
    macro generate_gset_link(struct_name::Symbol, link_prop_def::Expr)
    
        # 外加属性参数：`env_prop_name::env_type_name`
        link_prop_name::Symbol, link_type_name::Symbol = link_prop_def.args
    
        # 📌直接在代码中插入`get_$env_prop_name`不可取：报错「syntax: "env_prop_name(x::S)" is not a valid function argument name」
        get_func_name::Symbol = Symbol("get_$link_prop_name")
        set_func_name::Symbol = Symbol("set_$link_prop_name")
    
        quote # 插入「读写外加变量」定义
            "读取「外加属性」"
            $get_func_name(x::$struct_name)::$link_type_name = x.$link_prop_name
    
            "写入「外加属性」"
            function $set_func_name(x::$struct_name, value::$link_type_name)
                x.$link_prop_name = value
            end
    
            # 不使用「『外加属性』作为第一个位置参数」的方法定义：若参数只有一个，会触发递归
    
            # 疑难杂症：引入这个「新关键字参数」要报错「UndefKeywordError: keyword argument `$env_prop_name` not assigned」
            # "新外部构造方法：用关键字参数引入「外加属性」，但需要在其它参数都指定的情况下"
            # function $struct_name(args...; $env_prop_name::$env_type_name, args_kw...)
            #     @show $env_prop_name args args_kw
            #     $struct_name(args..., $env_prop_name; args_kw...)
            # end
        end |> esc # 避免被立即解析
    end
end

begin "其它辅助函数"

    export input, @input_str
    export import_external_julia_package

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

    """
        import_external_julia_package(package_paths::Union{AbstractArray, Tuple}, module_names::Union{AbstractArray, Tuple})::Dict{String,Module}
        
    导入路径&导入Julia包
    - 功能：根据现有的「包路径」与「模块名」，**动态**导入外部Julia模块
    - 返回：「模块名String => 模块对象Module」的字典（可被复用）
        - 【20230718 11:26:40】现在是用import把Module作为符号导出，而不再用using污染命名空间了！
    """
    function import_external_julia_package(
        package_paths::Union{AbstractArray, Tuple}, 
        module_names::Union{AbstractArray, Tuple}
        )::Dict{String,Module}
        # 添加所有路径
        push!(LOAD_PATH, package_paths...)
        @debug "Added paths $package_paths"

        # 导入所有包
        @debug "importing packages $module_names"

        result::Dict{String, Module} = Dict{String,Module}()
        for package_name in module_names
            m::Union{Module,Nothing} = nothing
            try # 每次都尝试一下（可能有「模块没找到」错误）
                @eval import $(Symbol(package_name))
                m = @eval $(Symbol(package_name))
                @debug "Imported $m module!!! XD"
                result[package_name] = m # 将模块放入返回值
            catch e
                @error "import_external_julia_package ==> $e"
            end
        end

        # 检查
        if (diff = length(module_names) - length(result)) > 0
            @error "模块未导入完全！缺少 $diff 个模块。以下是已导入模块：\n$result"
        end
        @debug "packages imported! result = $result"
        return result
    end
    
    import_external_julia_package(
        package_path::AbstractString, 
        module_names::Union{AbstractArray, Tuple}
        )::Dict{String,Module} = import_external_julia_package((package_path,), module_names)

    import_external_julia_package(
        package_path::AbstractString, 
        package_name::AbstractString
        )::Dict{String,Module} = import_external_julia_package((package_path,), (package_name,))
    
end

end