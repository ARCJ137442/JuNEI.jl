"""
注册项：作为一个Julia模块，直接对接(Open)Junars
- ！部分对接代码来自OpenJunars源码
- 参考：OpenJunars主页 <https://github.com/AIxer/OpenJunars>
"""

begin "CINOpenJunars"
    
    # 在此处export，保证完整性
    export CINJunars
    export showtracks
    
    "Junars的默认包名"
    const JUNARS_DEFAULT_MODULES::Vector{String} = [
        "Junars" # Junars主模块
        "DataStructures" # 启动NaCore所需的数据结构
    ]


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
        package_paths::Vector{String}
        package_names::Vector{String}

        "NARS核心"
        oracle # ::NaCore # 因「动态导入」机制限制，无法在编译时设定类型
        
        # "缓存的输入"
        # cached_inputs::Vector{String}
        
        "宽松的构造函数（但new顺序定死，没法灵活）"
        function CINJunars(
            package_paths::Vector{String},
            package_names::Vector{String} = JUNARS_DEFAULT_MODULES,
            out_hook::Union{Function, Nothing} = nothing, 
            # cached_inputs::Vector{String} = String[] # Julia动态初始化默认值（每调用就计算一次，而非Python中只计算一次）
            )
            new(
                NARSType"JuNARS",
                out_hook, 
                package_paths, 
                package_names, 
                # cached_inputs #=空数组=#
            )
        end

        "同上，唯一的不同就是可以只指定一个路径（与cjline兼容）"
        function CINJunars(
            package_path::String,
            package_names::Vector{String} = JUNARS_DEFAULT_MODULES,
            out_hook::Union{Function, Nothing} = nothing, 
            # cached_inputs::Vector{String} = String[] # Julia动态初始化默认值（每调用就计算一次，而非Python中只计算一次）
            )
            CINJunars(
                [package_path], # 变成向量
                package_names, 
                out_hook, 
                # cached_inputs #=空数组=#
            )
        end
    end

    "实现：复制一份副本（所有变量），但不启动"
    copy(cj::CINJunars)::CINJunars = CINJunars(
        cj.type,
        cj.package_paths,
        cj.package_names,
        cj.out_hook,
        # copy(cached_inputs), # 可变数组需要复制
    )
    "similar类似copy"
    similar(cj::CINJunars)::CINJunars = copy(cj)
    
    # 📝Julia对引入「公共属性」并不看好
    
    "存活依据：主进程非空"
    isAlive(cj::CINJunars)::Bool = 
        hasproperty(cj, :oracle) && # 是否有
        isdefined(cj, :oracle) && # 定义了吗
        !isnothing(cj.oracle) && # 是否为空
    # 先判断「有无属性」，再判断「是否定义」，最后判断「是否为空」
    
    "实现「启动」方法（生成指令，打开具体程序）"
    function launch!(cj::CINJunars)
        # *动态*导入外部Julia包
        import_external_julia_package(
            cj.package_paths,
            cj.package_names,
        )
        
        # try
            @eval begin
            # 生成
            cycles = Ref{UInt}(0)
            serial = Ref{UInt}(0)

            #=📌难点：生成Narsche报错
            「MethodError: no method matching Junars.Gene.Narsche{Junars.Entity.Concept}(::Int64, ::Int64, ::Int64)」
                method too new to be called from this world context.
                The applicable method may be too new: running in world age 33487, while current world is 33495.
            =#
            cache_concept = Narsche{Concept}(100, 10, 400)
            cache_task = Narsche{NaTask}(5, 3, 20)
            mll_task = MutableLinkedList{NaTask}()
            
            # 在代码块中使用「$局部变量名」把局部变量带入eval
            $cj.oracle = NaCore( # 确保这时候NaCore已经导入
                cache_concept, 
                cache_task, 
                mll_task, # 这个需要 DataStructures 模块
                serial, 
                cycles, 
            );

            # ignite($cj.oracle) # 启动Junars
            end
        # catch e
        #     @error "launch!: $e"
        # end
    end

    # 📌在使用super调用超类实现后，还能再派发回本类的实现中（见clear_cached_input!）
    "继承：终止程序（暂未找到比较好的方案）"
    function terminate!(cj::CINJunars)
        @debug "CINJunars terminate!"
        finalize(cj.oracle)
        cj.oracle = nothing # 置空
        @super CINProgram terminate!(cj) # 构造先父再子，析构先子再父
        @show cj # 测试
    end

    "重载：直接添加命令（不检测「是否启动」）"
    function put!(cj::CINJunars, input::String)
        # 增加一条指令
        add_one!(cj.oracle, input)
    end
    
    "（慎用）【独有】直接写入NaCore（迁移自OpenJunars）"
    function add_one!(nacore, input::String)
        try
            # 时间戳？
            stamp = Stamp(
            [nacore.serials[]],
            nacore.cycles[]
            )
            
            # 解析语句
            task = parsese(input, stamp)
            
            # 置入内部经验
            put!(nacore.internal_exp, task)

            # 时序+1？
            nacore.serials[] += 1
        catch e
            @error "add_one!: $e"
        end
    end
    
    "实现方法：推理循环步进"
    function cycle!(cj::CINJunars, steps::Integer)
        for _ in 1:steps
            try
                Junars.cycle!(cj.oracle) # 同名函数可能冲突？
            catch e
                @error "cycle! ==> $e"
            end
            # 【20230714 23:12:22】因cycle!中的「absorb!」方法，没法从buffer捕获新语句
            # 尝试在任务缓冲区追踪新增语句（源自OpenJunars inference\derivetask.jl）
            if !isempty(cj.oracle.taskbuffer)
                @show cj.oracle.taskbuffer
            end
            for task in cj.oracle.taskbuffer
                # 不能完全覆盖「Derived」输出的内容？
                @show task.sentence
            end
        end    
    end

    "打印跟踪（迁移自OpenJunars）"
    function showtracks(cj::CINJunars)
        # 获取概念集
        cpts = cj.oracle.mem
        # 遍历概念集
        for level in cpts.total_level:-1:1
            length(cpts.track[level]) == 0 && continue
            print("L$level: ")
            for racer in cpts.track[level]
                print("{$(name(racer)); $(round(priority(racer), digits=2))}")
            end
            println()
        end
    end
end