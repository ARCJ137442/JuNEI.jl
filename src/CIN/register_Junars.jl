"""
注册项：作为一个Julia模块，直接对接(Open)Junars
- ！部分对接代码来自OpenJunars源码
- 参考：OpenJunars主页 <https://github.com/AIxer/OpenJunars>
"""

begin "CINOpenJunars"
    
    # 在此处export，保证完整性
    export CINJunars
    # export cached_inputs, cache_input!, num_cached_input, cache_input!, clear_cached_input!, flush_cached_input! # 母文件已经导入
    export showtracks

    const MODULE_NAME_Junars::String = "Junars" # Junars主模块
    const MODULE_NAME_DataStructures::String = "DataStructures" # 启动NaCore所需的数据结构

    "Junars默认需导入的包名"
    const JUNARS_DEFAULT_MODULES::Vector{String} = [
        MODULE_NAME_Junars
        MODULE_NAME_DataStructures
    ]

    const TYPE_JUNARS::NARSType = NARSType"Junars"

    """Junars的JuNEI接口
    - 直接使用Junars代码访问
    """
    mutable struct CINJunars <: CINJuliaModule

        # 继承CINProgram #
        
        "存储对应CIN类型"
        type::NARSType
        
        "外接钩子"
        out_hook::Union{Function,Nothing}

        # 独有属性 #

        "模块路径&模块名"
        path_Junars::String
        module_names::Vector{String}
        
        """
        缓存的输入
        - 有可能是语句，也有可能是cycle步数
        - 🎯保证：
            - 可以在模块未激活时接收输入
            - 输入在后续被执行时，顺序不错乱
        """
        cached_inputs::Vector{Union{String, Integer}}

        """
        存储导入的Junars模块
        - 格式：「模块名 => 模块对象」
        - 一般持有的模块
            - `Junars`: 核心支持
            - `DataStructures`: 创建时需要的数据结构
        """
        module_Junars::Module
        module_DataStructures::Module

        "NARS核心"
        oracle # ::NaCore # 因「动态导入」机制限制，无法在编译时设定类型
        
        "宽松的构造方法（但new顺序定死，没法灵活）"
        function CINJunars(
            path_Junars::String,
            out_hook::Union{Function, Nothing} = nothing,
            module_names::Vector{String} = JUNARS_DEFAULT_MODULES,
            cached_inputs::Vector{String} = String[] # Julia动态初始化默认值（每调用就计算一次，而非Python中只计算一次）
            )
            new(
                TYPE_JUNARS,
                out_hook, 
                path_Junars, 
                module_names, 
                cached_inputs, #=空数组=#
                # 后续值使用「未定义」标签，以避免使用Union Nothing
            )
        end
        
        "来自Console.jl的统一调用方法"
        function CINJunars(
            ::NARSType, # 不使用
            path_Junars::String, # 与其它类型CIN一致
            out_hook::Union{Function, Nothing} = nothing, # 与其它类型CIN一致
            module_names::Vector{String} = JUNARS_DEFAULT_MODULES,
            cached_inputs::Vector{String} = String[] # Julia动态初始化默认值（每调用就计算一次，而非Python中只计算一次）
            )
            CINJunars(
                path_Junars,
                out_hook, 
                module_names, 
                cached_inputs, #=空数组=#
                # 后续值使用「未定义」标签，以避免使用Union Nothing
            )
        end
    end

    "实现：复制一份副本（所有变量），但不启动"
    Base.copy(cj::CINJunars)::CINJunars = CINJunars(
        cj.type,
        cj.path_Junars,
        cj.module_names |> copy, # 可变数组需要复制
        cj.out_hook,
        cj.modules |> copy, # 字典需要复制
        cj.oracle, # 【20230717 14:44:36】暂时直接复制引用
        cj.cached_inputs |> copy, # 可变数组需要复制
    )
    "similar类似copy"
    Base.similar(cj::CINJunars)::CINJunars = copy(cj)

    "（实现）实际上是构建一个新字典"
    modules(cj::CINJunars) = Dict(
        MODULE_NAME_Junars => cj.module_Junars,
        MODULE_NAME_DataStructures => cj.module_DataStructures
    )

    "（重载）只需检测Junars与DataStructures两个模块就行了"
    function check_modules(cj::CINJunars)::Bool
        return !@soft_isnothing_property(cj.module_Junars) && 
               !@soft_isnothing_property(cj.module_DataStructures)
    end

    # 📝Julia对引入「公共属性」并不看好
    
    "存活依据：Junars已载入 && 有推理器NaCore"
    isAlive(cj::CINJunars)::Bool = check_modules(cj) && !@soft_isnothing_property(cj.oracle)
    # 先判断「有无属性」，再判断「是否定义」，最后判断「是否为空」

    """
    根据CIN存储的模块引用，生成NaCore对象
    - 相关源码参考自Junars/run.jl

    📌难点：生成Narsche报错
    「MethodError: no method matching Junars.Gene.Narsche{Junars.Entity.Concept}(::Int64, ::Int64, ::Int64)」
        method too new to be called from this world context.
        The applicable method may be too new: running in world age 33487, while current world is 33495.
    
    📝原因：Julia不建议立即使用从外部「动态导入」而产生的「方法定义」
    - 解决方法：使用「Base.invokelatest」或「@invokelatest」避免「重新定义后无法立即调用」
    - 参考：
        - 中文：https://docs.juliacn.com/latest/manual/methods
        - 英文：https://docs.julialang.org/en/v1/manual/methods
    """
    function gen_nacore(cj::CINJunars) # NaCore

        # 检查模块导入情况
        !check_modules(cj) && return

        # 获取模块
        Junars::Module = cj.module_Junars
        DataStructures::Module = cj.module_DataStructures

        # 生成
        cycles, serial = Ref{UInt}(0), Ref{UInt}(0)
        cache_concept = @invokelatest Junars.Narsche{Junars.Concept}(100, 10, 400)
        cache_task = @invokelatest Junars.Narsche{Junars.NaTask}(5, 3, 20)
        mll_task = @invokelatest DataStructures.MutableLinkedList{Junars.NaTask}()

        return @invokelatest Junars.NaCore(
            cache_concept, 
            cache_task, 
            mll_task,
            serial, 
            cycles, 
        );
    end

    """
    （实现）「启动」方法
    - 异步导入Junars模块
    - 将导入的模块对象置入CIN
    - CIN使用「置入的模块对象」工作
    - （可选）除定义时记录的路径外，多导入几个额外路径
        - 📌源自「VSCode调试与直接运行的路径差异」
    """
    function launch!(cj::CINJunars, extra_paths...)
        # 📝在eval代码块中使用「$局部变量名」把局部变量带入eval
        # 动态异步启动
        @async begin
            try
                # *动态*导入外部Julia包（覆盖CIN模块字典）
                modules::Dict{String,Module} = import_external_julia_package(
                    (cj.path_Junars,extra_paths...), # 一个路径，变元组
                    cj.module_names,
                )

                # 置入指定模块
                cj.module_DataStructures = modules[MODULE_NAME_DataStructures]
                cj.module_Junars = modules[MODULE_NAME_Junars]
                
                # 生成推理器
                cj.oracle = gen_nacore(cj)

                # # 开启异步写入 【20230718 10:54:32】弃用：可能导致主进程阻塞
                # while isAlive($cj)
                #     @show flush_cached_input!($cj)
                # end
            catch e
                @error "launch! ==> $e"
                rethrow(e)
            end
        end
    end

    # 📌在使用super调用超类实现后，还能再派发回本类的实现中（见clear_cached_input!）
    "继承：终止程序（暂未找到比较好的方案）"
    function terminate!(cj::CINJunars)
        @debug "CINJunars terminate! $cj"
        finalize(cj.oracle)
        cj.oracle = nothing # 置空
        @invoke terminate!(cj::CINProgram) # 构造先父再子，析构先子再父
    end

    """
    重载：直接添加命令（不检测「是否启动」）
    - 【20230718 13:19:57】📌不能使用union{String,Integer}
        - 会产生歧义「MethodError: put!(::CINJunars, ::String) is ambiguous.」
    """
    function Base.put!(cj::CINJunars, input::String)
        # 过滤空值
        isempty(input) && return
        # 若可以被转换为整数：执行cycle
        n::Union{Int,Nothing} = tryparse(Int, input)
        !isnothing(n) && return cycle!(cj, n)
        # 正常字符串输入：向缓存区增加一条指令
        if isAlive(cj)
            flush_cached_input!(cj)
            add_one!(cj, input)
        else
            cache_input!(cj, input)
        end
    end
    
    "（慎用）【独有】直接写入NaCore（迁移自OpenJunars）"
    function add_one!(cj::CINJunars, input::String)
        nacore = cj.oracle
        Junars::Module = cj.module_Junars

        try # 注：使用invokelatest
            # 时间戳？
            stamp = @invokelatest Junars.Stamp(
                [nacore.serials[]],
                nacore.cycles[]
            )
            
            # 解析语句
            task = @invokelatest Junars.parsese(input, stamp)
            
            # 置入内部经验
            @invokelatest put!(nacore.internal_exp, task)

            # 时序+1？
            nacore.serials[] += 1
        catch e
            @error "add_one! ==> $e"
        end
    end

    """
    单步循环，但覆写(重新实现)`Junars.Control.cycle!`以便嵌入接口代码
    - 内部用于对接OpenJunars的模块
    - 注意：一切可能调用「外部模块定义的方法」的，都可能遇到「方法过新」的错误
        - 解决方法：在所有可能「方法过新」的方法调用处加上`@invokelatest`
    
    💭@assert 一切「Derived」派生出来的任务，在absorb前，不会被修改
    - 此即假设「此方法一定能捕捉到所有Derived的任务」
    - 【20230718 16:04:17】在现有测试中，似乎「读取缓冲区」的方法还是没法截取所有输出


    📝对于作为「MutableLinkedList」的缓冲区，不能直接for in遍历
    - 即便「先collect成Array然后再遍历」也不行
    - 需要「先copy再pop」的方法

    📝OpenJunars中Answer的来源：`cycle!/spike/reason/localmatch/trysolution!`
    - 目前尚无法进行捕捉
    """
    function cycle_one!(cj::CINJunars)
        # 引入模块
        Junars::Module = cj.module_Junars
        
        Control::Module = Junars.Control
        Entity::Module = Junars.Entity # putback!
        Admins::Module = Junars.Admins
        Gene::Module = Junars.Gene
        
        nac::Junars.NaCore = cj.oracle
        begin "来自OpenJunars 主要是在其中**嵌入**语句捕捉代码"

            nar = @invokelatest Admins.now(nac) # 从核心生成NARS
            concept = @invokelatest Gene.take!(nar.mem)
            if concept !== nothing
                # 保持被选中的概念时刻在线
                # @show 1 length(nar.taskbuffer)
                @invokelatest Entity.putback!(nar.mem, concept)
                # @show 2 length(nar.taskbuffer)
                @invokelatest Admins.attach!(nar, concept)
                # @show 3 length(nar.taskbuffer)
                @debug "Attach Nar to Concept: $(Junars.name(concept))"
                @invokelatest Control.spike!(nar)
                # @show 4 length(nar.taskbuffer) # 【20230718 15:01:10】主要还是spike中产生了派生任务
                @invokelatest Admins.clear!(nar) # TODO 好像是多余的,因为下次生成新的Nar的时候默认值就是nothing
                # @show 5 length(nar.taskbuffer) # 并且clear经源码验证，未对缓冲区动手脚
            end

            #= 赶在缓冲区被清除前，读取其中的「新内容」
            📌上面的`Admins.clear!`不清除任务缓冲区taskbuffer
            - 📌【20230721 21:50:51】注意：以下涉及Base模块的，需要增加`Base.`前缀以保险不出错
                - 出错代码：「no method matching copy(::DataStructures.MutableLinkedList{Junars.Entity.NaTask})」
            =#
            tb = @invokelatest Base.copy(nar.taskbuffer) # 复制一份，以免造成影响
            while !(@invokelatest Base.isempty(tb)) # 注意：不是nac.taskbuffer
                task = @invokelatest Base.pop!(tb) # 摘自`Control.absorb!`
                # （WIP）打印信息：句子名称(路径：sentence.jl/Gene.name)
                sentense::String = @invokelatest Gene.name(task.sentence)
                # @info "已捕捉到任务：" * sentense # 【20230718 14:52:26】不知为何@debug不显示
                # （对接）使用钩子
                use_hook(cj, sentense)
            end

            # 清除缓冲区
            @invokelatest Control.absorb!(nar)
            nac.cycles[] += 1
        end
    end

    "内部方法：推理循环步进（没有缓存）"
    function cycle_interfaced!(cj::CINJunars, steps::Integer)
        for _ in 1:steps
            # Junars.cycle!(cj.oracle) # 同名函数可能冲突？
            try
                cycle_one!(cj) # 在cycle_one 中执行捕捉操作
            catch e
                @error "cycle! ==> $e"
                rethrow(e)
            end
        end
    end
    
    "实现方法：推理循环步进"
    function cycle!(cj::CINJunars, steps::Integer)
        if isAlive(cj)
            flush_cached_input!(cj)
            cycle_interfaced!(cj, steps)
        else
            cache_input!(cj, steps)
        end
    end

    "打印跟踪（迁移自OpenJunars）"
    function showtracks(cj::CINJunars)
        # 获取概念集
        cpts = cj.oracle.mem
        Junars = cj.module_Junars
        # 遍历概念集
        for level in cpts.total_level:-1:1
            length(cpts.track[level]) == 0 && continue
            print("L$level: ")
            for racer in cpts.track[level]
                print("{$(Junars.name(racer)); $(round(Junars.priority(racer), digits=2))}")
            end
            println()
        end
    end

    "【独有】缓存的命令"
    cached_inputs(cj::CINJunars)::Vector{String} = cj.cached_inputs
    
    "缓存的输入数量" # 注：使用前置宏无法在大纲中看到方法定义
    num_cached_input(cj::CINJunars)::Integer = length(cj.cached_inputs)

    "将输入缓存（不立即写入CIN）"
    cache_input!(cj::CINJunars, input::Union{String,Integer}) = push!(cj.cached_inputs, input)

    "清除缓存的输入"
    clear_cached_input!(cj::CINJunars) = empty!(cj.cached_inputs)
    
    "（调用者在异步）将所有缓存的输入全部写入CIN，并清除缓存"
    function flush_cached_input!(cj::CINJunars)
        for cached_input::Union{String,Integer} ∈ cj.cached_inputs
            if cached_input isa Integer # 数字⇒循环一定步骤
                cycle_interfaced!(cj, cached_input)
            else # 字符串⇒语句输入
                add_one!(cj, cached_input)
            end
        end
        # 执行完毕后清除缓存
        clear_cached_input!(cj)
    end
end