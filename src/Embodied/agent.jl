"""
进一步封装：NARS与外界对接时的「智能体」角色
"""

# 导入

import ..Interface.CIN: getNARSType, getRegister, has_hook, out_hook!, isAlive, terminate!, cycle! # 仅import能为函数添加方法
using ..Interface.CIN

# 导出

export Agent_Stats, Agent

export getNARSType, getRegister
export has_hook, use_hook, out_hook!
export isAlive, terminate!, cycle!, activate!, update!
export goals, register!, praise!, punish!
export getOperations, numStoredOperations, remind_operations, 
       store!, reduce!, clear_stored_operations, operations_itor,
       operation_snapshot!
export babble, babble!

begin "Agent Stats"

    "NARS智能体的统计（可变对象）"
    mutable struct Agent_Stats
        total_sense_inputs::Unsigned
        total_initiative_operations::Unsigned
        total_unconscious_operations::Unsigned
    end

    "默认构造方法：产生空值"
    Agent_Stats() = Agent_Stats(0, 0, 0)

    "析构函数"
    function Base.finalize(stats::Agent_Stats)
        empty!(stats)
    end

    "复制一个统计对象（struct不会默认派发到copy方法）"
    Base.copy(stats::Agent_Stats) = Agent_Stats(
        stats.total_sense_inputs,
        stats.total_initiative_operations,
        stats.total_unconscious_operations,
    )

    "清空统计数据"
    function Base.empty!(stats::Agent_Stats)
        stats.total_sense_inputs = 0
        stats.total_initiative_operations = 0
        stats.total_unconscious_operations = 0
    end
end

begin "Agent"

    """
    从CIN到交互的示例2：NARS智能体（无需可变）
    - 🎯面向游戏调用
    - 📄内置Agent
    - 🔬展示「如何封装CIN」的高级例子

    【20230721 11:04:57】因其对象的「引用」性质，采用「不可变类型」定义
    - 可能的缺点：其引用无法在析构函数中被删去，故垃圾回收可能有问题
    """
    struct Agent

        # CIN
        program::CINProgram # 一个Agent，一个Program

        # 目标
        goals::Vector{Tuple{Goal,Bool}} # Goal, is_negative

        # 感知
        sensors::Vector{AbstractSensor}

        # 操作
        operations::Dict{Operation, Unsigned}

        # 统计
        stats::Agent_Stats # 一个Agent，一个Stats

        # 运行

        "总体调控NARS智能体的「推理频率」，对应PyNEI的「inference_cycle_frequency」"
        cycle_speed::Integer

        """背景本能系统
        对应关系：Babble⇔Background Inheriant System
        - 类型：智能体+感知→操作
            - 格式：function (agent::Agent, perceptions::Vector{Perception})::Vector{Operation}
        - 功能：在Agent「尚未能自主决策」时，调用该「必定能决策」的系统
        - 默认情况：随机选取
        """
        babble_hook::Function

    end

    """
    正常（外部）构造方法：提供默认值
    - 📝内部构造方法new不支持关键字参数
        - 强行使用关键字参数则报错：「syntax: "new" does not accept keyword arguments around 」
    - 📝Julia建议的「构造方法」分工：
        - 内部构造方法：用于「参数约束」「错误检查」
        - 外部构造方法：用于「提供默认值」「类型转换」
    
    > [!中文文档](https://docs.juliacn.com/latest/manual/constructors/)
    > 提供尽可能少的内部构造方法是一种良好的形式：
    > 仅在需要显式地处理所有参数，以及强制执行必要的错误检查和转换时候才使用内部构造。
    > 其它用于提供便利的构造方法，比如提供默认值或辅助转换，应该定义为外部构造函数，然后再通过调用内部构造函数来执行繁重的工作。
    > 这种解耦是很自然的。
    """
    function Agent(
        type::NARSType, 
        executable_path::String;
        cycle_speed::Integer = 1,
        babble_hook::Function = babble, # 占位符（默认方法）
        goals::Vector{Tuple{Goal,Bool}} = Tuple{Goal,Bool}[], # 默认为空
        sensors::Vector{AbstractSensor} = AbstractSensor[], # 默认为空
        operations::Dict{Operation, Unsigned} = Dict{Operation, Unsigned}(), # 默认为空
        stats::Agent_Stats = Agent_Stats(), # 默认构造
        )
        
        # 先构造自身
        agent = Agent(
            CINProgram(
                type, # 传入Agent
                executable_path, # 可执行文件路径
                identity, # 占位符
            ),
            goals, # 空值
            sensors, # 空值
            operations, # 操作集
            stats,
            cycle_speed,
            babble_hook,
        )
        
        # 再闭包传输（需要先定义agent），内联其中的Program而不改变Agent本身
        out_hook!(agent, line -> use_hook(agent, line))

        return agent
    end

    # 需要在内部构造方法中使用，在外部则只能访问到上面那个构造方法
    "复制一份副本（所有变量，包括统计），但不启动"
    Agent(agent::Agent) = new(
        copy(agent.program), # 复制程序
        copy(agent.goals),
        copy(agent.sensors),
        copy(agent.operations),
        copy(agent.stats),
        agent.cycle_speed,
        agent.babble_hook,
    )

    begin "方法区"

        #= 存取 =#

        "复制副本（见构造方法）"
        Base.copy(agent::Agent)::Agent = Agent(agent)
        Base.similar(agent::Agent)::Agent = copy(agent)

        #= Program继承 =#

        "同Program"
        getNARSType(agent::Agent)::NARSType = getNARSType(agent.program)
        
        "同Program（不使用`::CINRegister`以实现代码解耦）"
        getRegister(agent::Agent) = getRegister(agent.program)
    
        "同Program"
        has_hook(agent::Agent)::Bool = has_hook(agent.program)
    
        # "同Program" # 与下面的use_hook冲突
        # use_hook(agent::Agent, content::String) = use_hook(agent.program, content)
        
        "同Program"
        out_hook!(agent::Agent, newHook::Union{Function,Nothing})::Union{Function,Nothing} = out_hook!(agent.program, newHook)

        "同Program"
        isAlive(agent::Agent) = isAlive(agent.program)
        
        "同Program"
        terminate!(agent::Agent) = terminate!(agent.program)
        
        "同Program（使用参数展开，让Program自行派发）"
        Base.put!(agent::Agent, input::String) = put!(agent.program, input)

        "针对「可变长参数」的多项输入（派发到最上方put）" # 不强制inputs的类型
        function Base.put!(agent::Agent, input1, input2, inputs...) # 不强制Nothing
            # 使用多个input参数，避免被派发到自身
            put!(agent, (input1, input2, inputs...))
        end
    
        "针对「可变长参数」的多项输入（派发到最上方put）" # 不强制inputs的类型
        function Base.put!(agent::Agent, inputs::Union{Vector,Tuple}) # 不强制Nothing
            # 注意：Julia可变长参数存储在Tuple而非Vector中
            for input ∈ inputs
                # @show input typeof(input)
                put!(agent, input)
            end
        end

        "同Program"
        cycle!(agent::Agent, steps::Integer) = cycle!(agent.program, steps)

        "重载默认值：使用「cycle_speed」属性"
        cycle!(agent::Agent) = cycle!(agent.program, agent.cycle_speed)

        #= 控制 =#

        "默认输出钩子（包括agent对象「自身」）"
        function use_hook(agent::Agent, line::String)
            # ENABLE_INFO && @info "Agent catched: $line" # 【20230710 15:59:50】Game接收正常
            # try # 【20230710 16:22:45】操作捕捉测试正常
                operation::Operation = getRegister(agent).operation_catch(line)
                if !isempty(operation)
                    # @show operation operation.parameters # 【20230710 16:51:15】参数检验（OpenNARS）正常
                    Embodied.ENABLE_INFO && @info "EXE #$(agent.stats.total_initiative_operations): $operation at line「$line」"
                    hook_operation!(agent, operation)
                end
            # catch e
            #     @error e
            # end
        end

        "启动（类似Program）"
        function activate!(agent::Agent)
            launch!(agent.program) # 启动CIN程序
        end

        """
        更新智能体本身
        返回：更新中获取到的所有感知
        """
        function update!(agent::Agent, sense_targets...; sense_targets_kw...)::Vector{Perception}
            perceptions::Vector{Perception} = update_sensors!(agent, sense_targets...; sense_targets_kw...) # 更新感知器
            update_goals!(agent) # 更新目标
            cycle!(agent) # 推理步进
            return perceptions
        end

        """
        更新智能体本身，但加上「无操作⇒babble」的逻辑
        
        📝若用关键字参数重载，可能会影响派发逻辑：导致「新增关键字参数成必要」
        - 添加后使用「旧的关键字参数」会报错「UndefKeywordError: keyword argument `auto_babble` not assigned」
        - 
        """
        function update!(agent::Agent, auto_babble::Bool, sense_targets...; sense_targets_kw...)::Vector{Perception}
            perceptions::Vector{Perception} = update!(agent, sense_targets...; sense_targets_kw...) # 调用先前的方法

            # 无操作输出：检测存储的操作是否有输出⇒一直babble直到输出
            auto_babble && if numStoredOperations(agent) <= 0
                babble!(agent, perceptions) # 这里承诺「必然有输出？」
            end

            return perceptions
        end

        "复现PyNEI中的「update_sensors」"
        function update_sensors!(agent::Agent, sense_targets...; sense_targets_kw...)
            # 收集所有感知
            perceptions::Vector{Perception} = collect_all_perceptions(agent, sense_targets...; sense_targets_kw...)
            # 加入感知
            for perception in perceptions
                # 加入命令
                put!(agent, perception)
                # 添加统计
                agent.stats.total_sense_inputs += 1
            end
            return perceptions
        end

        """
        从感知器中获取所有「NARS感知」，并存放到指定「收集器」中
        - 感知器传参格式：感知器(收集器, Agent对象, 其它参数)
        """
        function collect_all_perceptions(agent::Agent, sense_targets...; sense_targets_kw...)::Vector{Perception}
            # 建立收集器
            result::Vector{Perception} = Perception[]
            # 收集感知
            for sensor!::AbstractSensor in agent.sensors
                #= 向各个感知器传参传参
                - 📌传参约定：前两个参数固定为：收集器，Agent自身
                    - ⚠注意：这里*固定传入*的参数Agent，在Sensor中是「附加感知项」
                =#
                sensor!(result, agent, sense_targets...; sense_targets_kw...)
            end
            # 返回感知
            # @show result
            return result
        end

        "更新智能体目标"
        function update_goals!(agent::Agent)
            for (goal::Goal, is_negative::Bool) in agent.goals
                put!(agent, goal, is_negative)
            end
        end

        #= 输入+调用模板（没必要内置到CINProgram中） =#
        
        # 目标
        
        "返回所有已注册的目标（无「是否负向」，生成器）"
        goals(agent::Agent)::Base.Generator = (
            goal # 只保留目标
            for (goal,_) in agent.goals
        )

        "添加目标（派发Goal）入Program"
        function Base.put!(agent::Agent, goal::Goal, is_negative::Bool)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).put_goal(goal, is_negative)
            )
        end

        "注册目标：将目标存入"
        function register!(agent::Agent, goal::Goal, is_negative::Bool=false)
            push!(agent.goals, (goal, is_negative))
        end
        
        "奖励目标"
        function praise!(agent::Agent, goal::Goal)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).praise(goal)
            )
        end
        
        "惩罚目标"
        function punish!(agent::Agent, goal::Goal) # 不强制Nothing
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).punish(goal)
            )
        end
        
        # 感知

        "添加感知器"
        function register!(agent::Agent, s::AbstractSensor)
            # Embodied.ENABLE_INFO && @info "registering..." # 【20230710 17:18:54】注册测试正常
            s ∉ agent.sensors && push!(agent.sensors, s) # 考虑把sensors当做一个集合？
        end

        "添加感知"
        function Base.put!(agent::Agent, np::Perception)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).sense(np)
            )
        end

        # 操作

        "返回所有已注册的操作（类列表形式，可collect）"
        getOperations(agent::Agent)::Base.KeySet = keys(agent.operations)

        "返回缓存的操作数量（值的总和）"
        numStoredOperations(agent::Agent)::Integer = agent.operations |> values |> sum

        "添加无意识操作（用Operation重载put!，对应PyNEI的put_unconscious_operation）入Program" # TODO：是否可以将其和put!整合到一起？（put一个操作）
        function Base.put!(agent::Agent, op::Operation)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).babble(op) # 注意：无需判断了，只需要「输入无效」就能实现同样效果
            )
        end
        
        "添加「操作注册」入Program：让NARS「知道」有这个操作（对应PyNEI的register_basic_operation）"
        function register!(agent::Agent, op::Operation)
            # 置入语句
            @debug "register operation $op"
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).register(op)
            )
            # 在存储结构中刷新操作（20230706 23:48:39 必须，不然不叫「注册」）
            if !haskey(agent.operations, op)
                agent.operations[op] = 0
            end
        end

        "重新提醒「自己有操作」"
        function remind_operations(agent::Agent)
            for operation in agent.operations
                register!(agent, operation)
            end
        end

        "存储操作"
        function store!(agent::Agent, operation::Operation, num::Integer=1)
            if haskey(agent.operations, operation)
                agent.operations[operation] += num
            else
                agent.operations[operation] = num
                # Embodied.ENABLE_INFO && @info "Registered new operation as key: $operation"
            end
        end

        "消耗/减少操作 = 存储相反数"
        function reduce!(agent::Agent, operation::Operation, num::Integer=1)
            store!(agent, operation, -num)
        end

        "清除已存储的操作：默认所有"
        function clear_stored_operations(agent::Agent)
            for key in keys(agent.operations)
                agent.operations[key] = 0
            end
        end

        """
        清除已存储的操作：限定范围
        - ⚠注意：此处直接将对应键置零以平衡效率，可能会新增键值对
        """
        function clear_stored_operations(agent::Agent, op_range)
            for key in op_range
                agent.operations[key] = 0
            end
        end

        "支持「空置」：利用多分派而非类型判断(isnothing)"
        clear_stored_operations(agent::Agent, ::Nothing) = clear_stored_operations(agent, keys(agent.operations))

        "处理CIN输出的操作"
        function hook_operation!(agent::Agent, operation::Operation)
            # 存储操作
            store!(agent, operation)
            # 添加统计
            agent.stats.total_initiative_operations += 1
        end
        
        "调用「背景本能系统」：无意识操作"
        function babble!(agent::Agent, perceptions::Vector{Perception})::Vector{Operation}
            # 从「背景本能系统」中获取操作
            operations::Vector{Operation} = agent.babble_hook(agent, perceptions)
            for operation in operations
                # 添加无意识操作
                put!(agent, operation)
                # 存储操作 （绕过统计）
                store!(agent, operation)
                # 添加统计
                agent.stats.total_unconscious_operations += 1
            end
            return operations
        end

        "默认babble：随机选取已注册的操作"
        function babble(agent::Agent, perceptions::Vector{Perception})::Vector{Operation}
            # 获取所有可用操作，使用rand随机选取
            operations::Vector{Operation} = agent |> getOperations |> collect
            return (
                isempty(operations) ? 
                operations : 
                Operation[
                    operations |> rand
                ]
            )
        end

        begin "对接应用"

            """
            返回所有操作的迭代器（不论存量是否为零）
            - 📌格式约定：(操作, 操作次数)
            """
            operations_itor(agent::Agent) = (
                (op, num)
                for (op,num) in agent.operations
            )

            """
            操作快照：遍历获取到第一个操作，返回&清除已存储的操作
            - filterSet：只过滤某个范围的操作
                - 默认: nothing(无范围)，即清除所有操作
            """
            function operation_snapshot!(agent::Agent, filterSet)::Operation
                for op in intersect(filterSet, keys(agent.operations)) # 交集以确认其被存储过
                    if agent.operations[op] > 0 # 若有存储过操作
                        Embodied.ENABLE_INFO && @info "agent $(nameof(op))!"
                        clear_stored_operations(agent, filterSet) # 清空其它操作
                        return op
                    end
                end
                # 找不到：返回空操作
                return Operation""
            end

            """
            当「过滤集」空置时的版本
            - 利用多分派机制，减少类型判断
            """
            function operation_snapshot!(agent::Agent, filterSet::Nothing=nothing)::Operation
                for op in keys(agent.operations)
                    if agent.operations[op] > 0 # 若有存储过操作
                        Embodied.ENABLE_INFO && @info "agent $(nameof(op))!"
                        clear_stored_operations(agent, filterSet) # 清空其它操作
                        return op
                    end
                end
                # 找不到：返回空操作
                return Operation""
            end
        end
    end
end
