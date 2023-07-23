# 统一放置export
export AbstractSensor, SensorBasic
export enabled, perceive_hook, collect_perception!

export AbstractPerceptionFilter, FilterDifference, FilterZScore, FilterChain
export has_baseline

export SensorFiltered, SensorDifference

begin "抽象感知器 & 基础感知器"

    """抽象出一个「NARS感知器」

    主要功能：作为NARS感知的处理器，根据环境提供的参数生成相应「NARS感知」
    - 主要函数：被调用 -> 向收集器里添加感知
        - 调用约定：`感知器对象(收集器, 其它参数)`
    - 默认约定的「共有字段」（在未重载前使用的函数，推荐用函数而非字段）
        - enabled：是否使能
        - perceive_hook：外调函数
    """
    abstract type AbstractSensor end

    "（默认：开关状态字段）属性「是否使能」"
    enabled(s::AbstractSensor) = s.enabled

    """
    （默认：字段perceive_hook）属性「外调函数」
    - 约定：`perceive_hook(收集器, 其它附加参数)::Union{Vector{Perception}, Nothing}`
        - 参数：第一个*位置参数*必定是「收集器」对象
        - 返回值：Perception（若需自动添加）/nothing（无需自动添加）
        - 🔗见下面`collect_perception!`对钩子的调用
    """
    perceive_hook(s::AbstractSensor) = s.perceive_hook

    """
    （默认）在不检查enabled的情况下：直接执行「外调函数」，
    - 将「收集器」也传递到外调函数，以供参考
        - 后续可以让外调函数「根据已有感知做出对策」
        - 【20230721 17:18:19】现统一感知方式：只让「外调函数」对「收集器」进行增删操作
            - ⚠不处理其返回值！
            - 缘由：减少对接复杂度
    - 【20230716 23:12:54】💭不把Sensor作为参数传递的理由
        - 「从其它参数中返回感知对象」暂不需要「感知器本身」参与
        - 📌范式：若需要在「输出感知」层面进行功能增加（如「累积统计」功能），
            更推荐「扩展新类」而非「将外调函数复杂化」
    """
    function collect_perception!(
        sensor::AbstractSensor, 
        collector::Vector{Perception}, 
        targets...; targets_kw...
        ) # 返回值不重要
        (perceive_hook(sensor))(collector, targets...; targets_kw...)
    end

    "直接调用：（在使能的条件下）执行感知（返回值不使用）"
    function (s::AbstractSensor)(
        collector::Vector{Perception}, # 收集器
        targets...; # 位置参数
        targets_kw... # 关键字参数
        ) # 返回值不重要
        enabled(s) && collect_perception!(s, collector, targets...; targets_kw...)
    end

    "字符串显示"
    Base.string(s::AbstractSensor)::String = "<NARS $(typeof(s)) -$(enabled(s) ? "-" : "×")> $(perceive_hook(s))>"

    "插值显示=字符串"
    Base.repr(s::AbstractSensor)::String = string(s)

    "同步在show中的显示代码"
    @redefine_show_to_to_repr s::AbstractSensor


    """
    基础感知器：一个最简单的感知器
    - 功能：在被调用时，直接返回其「外调函数」返回的感知对象
    - 一切都遵循其父抽象类的**默认处理方式**
    """
    mutable struct SensorBasic <: AbstractSensor
        enabled::Bool
        perceive_hook::Function # 20230710 15:48:03 现不允许置空

        "构造方法"
        SensorBasic(
            perceive_hook::Function,
            enabled::Bool=true, # 默认值
        ) = new(enabled, perceive_hook)
    end

end

begin "感知过滤器：抽象于「有过滤的感知器」"

    "抽象的「感知过滤器」"
    abstract type AbstractPerceptionFilter end

    "（API）直接调用：收集器&感知信息⇒(可能的改变自身)⇒信号「是否要感知器输出」"
    (::AbstractPerceptionFilter)(collector, targets...; targets_kw...) = @abstractMethod

    "（默认）字符串显示"
    Base.string(apf::AbstractPerceptionFilter)::String = "#$(typeof(apf))#"

    "格式化显示"
    Base.repr(apf::AbstractPerceptionFilter) = Base.string(apf)

    "重定义show方法到repr"
    @redefine_show_to_to_repr apf::AbstractPerceptionFilter

end

begin "差分过滤器"

    """
    ⚙️差分感知过滤器：只对「信号的变化」敏感
    - 作为「只对变化敏感」的感知器，其**只在信号发生变化**时才输出
    - 输出机制：生成「当前基线」⇒基线比对⇒差分输出
        1. 对输入的感知→记忆函数生成「当前记忆」
        2. 与「感知基线」作比对
            - 若同：不输出
            - 若异：输出至收集器，并划定新基线
    - 「基线函数」约定：`baseline_hook(收集器, 其它附加参数)::Any`
        - 参数类型：同「外调函数」
        - 返回类型：任意（可比）值
    - 启发来源：[2021年会报告](https://www.bilibili.com/video/BV1ND4y1w7M5?t=1299.6&p=9)
    
    > 感觉系统不是对所有信号敏感，而是对信号的变化敏感。
    > 感觉信号没有逻辑意义的真值，但有信号意义的真值。
    """
    mutable struct FilterDifference{BaselineType} <: AbstractPerceptionFilter

        "基线函数：目标对象→基线参考（产生用于对比的值）"
        baseline_hook::Function

        "差异函数：两个「基线对象」→「是否有差异」"
        distinct_function::Function # (::BaselineType, ::BaselineType)::Bool

        "所谓「感知基线」"
        baseline::BaselineType # 【20230716 23:16:49】放最后是为了使用「未定义」状态

        "构造方法"
        function FilterDifference{BaselineType}(
            baseline_hook::Function, # 默认和「外调钩子」是一样的
            distinct_function::Function=(≠), # 默认为「不等号」
        ) where BaselineType
            new{BaselineType}(
                baseline_hook,
                distinct_function,
                # nothing # 使用「未定义」形式规避「类型转换」问题（Union不是首选）
            )
        end

        "语法糖：不指定类型⇒默认Any"
        FilterDifference(a...;k...) = FilterDifference{Any}(a...;k...)
    end

    "属性「是否有基线」：检测「先前是否已经感知过」"
    has_baseline(s::FilterDifference) = isdefined(s, :baseline)

    "（重载）字符串显示"
    Base.string(fd::FilterDifference)::String = "#<$(fd.baseline_hook)>$(typeof(fd))<$(fd.distinct_function)>#"

    """
    （实现）直接调用：感知信息⇒参考对象⇒比对⇒返回「感知器是否要输出」
    1. 先执行`baseline_hook`，返回「作为基线的参考对象」
    2. 把`baseline_hook`返回的「参考对象」与已有的「基线对象」作比对
        - 若同：不对收集器作处理
        - 若异：
            1. 运行`perceive_hook`，真正生成`Perception`对象并将此添加至收集器
            2. 返回true，让感知器知道「需要输出感知」
    """
    function (filter::FilterDifference{BaselineType})(collector, targets...; targets_kw...)::Bool where BaselineType
        # 构造「参考对象」
        reference::BaselineType = filter.baseline_hook(collector, targets...; targets_kw...)
        if !has_baseline(filter) || filter.distinct_function(filter.baseline, reference) # 使用自定义的「差异函数」
            # 更新自身状态
            filter.baseline = reference
            # 告知感知器
            return true
        end
        # 否则「按兵不动」
        return false
    end

end

begin "z-分数过滤器"

    """
    Z分数过滤器
    - 「基线函数」把感知到的数据全部量化成数值
    - 「比较函数」以「参考对象」与「基线」的Z-分数为基础
    """
    mutable struct FilterZScore{BaselineType} <: AbstractPerceptionFilter

        "量化钩子"
        quantify_hook::Function

        "评估函数：评估新数据的「Z-分数」"
        evaluate_function::Function

        "所谓「感知基线」"
        baseline::CMS{BaselineType} # 使用CMS构建

        "构造方法"
        function FilterZScore{BaselineType}(
            quantify_hook::Function,
            evaluate_function::Function,
        ) where BaselineType
            new{BaselineType}(
                quantify_hook,
                evaluate_function,
                # 置「未定义」
            )
        end

        "语法糖：不指定类型⇒默认Number"
        FilterZScore(a...;k...) = FilterZScore{Number}(a...;k...)
    end

    "属性「是否有基线」：检测「先前是否已经感知过」"
    has_baseline(fz::FilterZScore) = isdefined(fz, :baseline)

    "（重载）字符串显示"
    Base.string(fz::FilterZScore)::String = "#<$(fz.quantify_hook)>$(typeof(fz))<$(fz.evaluate_function)>#"

    """
    （实现）直接调用：感知信息⇒参考对象⇒比对⇒返回「感知器是否要输出」
    1. 先执行`baseline_hook`，返回「作为基线的参考对象」
    2. 把`baseline_hook`返回的「参考对象」与已有的「基线对象」作比对
        - 若同：不对收集器作处理
        - 若异：
            1. 运行`perceive_hook`，真正生成`Perception`对象并将此添加至收集器
            2. 返回true，让感知器知道「需要输出感知」
    """
    function (fz::FilterZScore{BaselineType})(collector, targets...; targets_kw...)::Bool where BaselineType
        # 构造「参考对象」
        reference::BaselineType = fz.quantify_hook(collector, targets...; targets_kw...)
        # 无基线：初始化「基线」(CMS对象初始化)
        if !has_baseline(fz)
            fz.baseline = CMS(
                reference, # 均值
                reference .^ 2, # 均值的平方
            )
            fz.baseline[] = 1 # 手动设置其「样本量」为1
        end
        if z_score(fz.baseline, reference) |> fz.evaluate_function # 使用自定义的「评估函数」评估「Z分数」
            # 更新自身状态
            fz.baseline(reference)
            # 告知感知器
            return true
        end
        # 否则「按兵不动」
        return false
    end
end

begin "级联过滤器"

    "级联过滤器：把上一个过滤器的输出，看做下一个过滤器的输入条件"
    struct FilterChain <: AbstractPerceptionFilter

        "过滤器序列（只持有引用）"
        filters::Vector{AbstractPerceptionFilter}

        "构造方法"
        FilterChain(filters...) = new(filters |> collect |> Vector{AbstractPerceptionFilter})
    end

    "（重载）字符串显示"
    Base.string(fc::FilterChain)::String = "#<=$(join(fc.filters, "~"))=>#"

    """
    （实现）直接调用：链式调用所有过滤器
    """
    function (fz::FilterChain)(collector, targets...; targets_kw...)::Bool
        for filter::AbstractPerceptionFilter in fz.filters
            # 若其中一个过滤器过滤掉了
            if !filter(collector, targets...; targets_kw...)
                return false
            end
        end
        # 若所有过滤器都通过了
        return true
    end

    "trick：用加法实现级联"
    Base.:(+)(fs::Vararg{AbstractPerceptionFilter}) = FilterChain(fs...) # 多个一般过滤器级联
    Base.:(+)(fc::FilterChain, f2::AbstractPerceptionFilter) = FilterChain((fc.filters)...,f2) # 「级联过滤器」与「一般过滤器」相加
    Base.:(+)(f1::AbstractPerceptionFilter, fc::FilterChain) = FilterChain(f1,(fc.filters)...) # 同上
    Base.:(+)(fc1::FilterChain, fc2::FilterChain) = FilterChain((fc1.filters)...,(fc2.filters)) # 两个「级联过滤器」尝试平铺

end

begin "过滤感知器"
    
    """
    【20230717 15:18:40】原「差分感知器」
    - 持有一个「过滤器」：输入感知，输出「是否要输出」
    """
    mutable struct SensorFiltered <: AbstractSensor
        enabled::Bool
        perceive_hook::Function

        "过滤器"
        filter::AbstractPerceptionFilter

        "构造方法"
        function SensorFiltered(
            perceive_hook::Function, # 只有在「基线」更新时起效
            filter::AbstractPerceptionFilter, # 过滤器
            enabled::Bool=true,
        )
            new(
                enabled,
                perceive_hook,
                filter
            )
        end
    end

    """
    兼容式构造方法：兼容先前「差分感知器」
    - 【20230717 15:41:08】唯一不足点：函数中没法使用泛型SensorDifference{BaselineType}
    - 【20230721 20:42:10】新范式：「基线函数」跟随「外调函数」的设定现不可取
        - 因：「外调函数只能通过修改collector进行操作」的新范式
    """
    function SensorDifference(
        BaselineType::DataType,
        perceive_hook!::Function, # 只有在「基线」更新时起效
        baseline_hook::Function, # 
        distinct_function::Function=(≠), # 默认为「不等号」
        enabled::Bool=true,
        )
        SensorFiltered(
            perceive_hook!,
            FilterDifference{BaselineType}(
                baseline_hook,
                distinct_function
            ),
            enabled,
        )
    end

    """
    兼容式构造方法：没BaselineType默认Any
    """
    function SensorDifference(
        perceive_hook::Function, # 只有在「基线」更新时起效
        baseline_hook::Function,
        distinct_function::Function=(≠), # 默认为「不等号」
        enabled::Bool=true,
        )
        SensorDifference(
            Any, 
            perceive_hook,
            baseline_hook,
            distinct_function,
            enabled,
        )
    end

    "（重载）字符串显示"
    Base.string(s::SensorFiltered)::String = "<NARS $(typeof(s)) | $(s.filter) -$(enabled(s) ? "-" : "×")> $(s.perceive_hook)>"

    "格式化显示"
    Base.repr(s::SensorFiltered) = Base.string(s)

    "重定义show方法到repr"
    @redefine_show_to_to_repr s::SensorFiltered

    """
    （重载）过滤感知：在不检查enabled的情况下，
    1. 让过滤器接受「所有感知信息」
        1. 自身状态可能更新
        2. 等待过滤器回应：是否「输出感知」
    2. 若过滤器返回true，则输出感知
    """
    function collect_perception!(
        sensor::SensorFiltered, 
        collector::Vector{Perception}, 
        targets...; targets_kw...
        )
        # 先用「过滤器」过滤感知(可能改变过滤器本身)
        if sensor.filter(collector, targets...; targets_kw...)
            # 使用「外调函数」
            perceptions::Union{Vector{Perception},Nothing} = sensor.perceive_hook(collector, targets...; targets_kw...)
            # 若非空，添加感知
            !isnothing(perceptions) && !isempty(perceptions) && push!(
                collector,
                perceptions...
            )
        end
    end

end
