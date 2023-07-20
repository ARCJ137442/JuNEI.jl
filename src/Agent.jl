"""
进一步封装：NARS与外界对接时的「智能体」角色
"""
module NARSAgent

# 导入
using Reexport
@reexport import Base: copy, similar, put!, empty!

using ..NARSElements

import ..CIN: getNARSType, getRegister, has_hook, out_hook!, isAlive, terminate!, cycle! # 仅import能为函数添加方法
using ..CIN

# 导出

export Agent_Stats, Agent

export getNARSType, getRegister
export has_hook, use_hook, out_hook!
export isAlive, terminate!, cycle!, activate!, update!
export goals, register!, praise!, punish!
export getOperations, numStoredOperations, remind_operations, 
       store!, reduce!, clear_stored_operations, operations_itor
export babble, babble!

begin "Agent Stats"

    "NARS智能体的统计（可变对象）"
    mutable struct Agent_Stats
        total_sense_inputs::Unsigned
        total_initiative_operations::Unsigned
        total_unconscious_operations::Unsigned
    end

    "默认构造函数：产生空值"
    Agent_Stats() = Agent_Stats(0,0,0)

    "复制一个统计对象（struct不会默认派发到copy方法）"
    copy(stats::Agent_Stats) = Agent_Stats(
        stats.total_sense_inputs,
        stats.total_initiative_operations,
        stats.total_unconscious_operations,
    )

    "清空统计数据"
    function empty!(stats::Agent_Stats)
        stats.total_sense_inputs = 0
        stats.total_initiative_operations = 0
        stats.total_unconscious_operations = 0
    end
end

begin "Agent"

    """从CIN到交互的示例2：NARS智能体（无需可变）
    - 🎯面向游戏调用
    - 📄内置Agent
    - 🔬展示「如何封装CIN」的高级例子
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
        babble_hook::Function # 是否要为了「让其可变」而让整个类mutable？

        "正常构造函数"
        function Agent(
            type::NARSType, 
            executable_path::String; # 内部构造函数可以接受关键字参数
            cycle_speed::Integer=1,
            babble_hook::Function=babble, # 占位符
            )
            
            # 先构造自身
            agent = new(
                CINProgram(
                    type, # 传入Agent
                    executable_path, # 可执行文件路径
                    identity, # 占位符
                ),
                Tuple{Goal,Bool}[], # 空值
                AbstractSensor[], # 空值
                Dict{Operation, Unsigned}(),
                Agent_Stats(), # 空值（注意：结构体的new不支持关键字参数，）
                cycle_speed, # 强行使用关键字参数则报错：「syntax: "new" does not accept keyword arguments around 」
                babble_hook,
            )
            
            # 闭包传输（需要先定义agent）
            out_hook!(agent, line -> use_hook(agent, line))

            return agent
        end

        # 需要在内部构造函数中使用，在外部则只能访问到上面那个构造函数
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
    end

    begin "方法区"

        #= 存取 =#

        "复制副本（见构造函数）"
        copy(agent::Agent)::Agent = Agent(agent)
        similar(agent::Agent)::Agent = copy(agent)

        #= Program继承 =#

        "同Program"
        getNARSType(agent::Agent)::NARSType = getNARSType(agent.program)
        
        "同Program"
        getRegister(agent::Agent)::CINRegister = getRegister(agent.program)
    
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
        put!(agent::Agent, input::String) = put!(agent.program, input)

        "针对「可变长参数」的多项输入（派发到最上方put）" # 不强制inputs的类型
        function put!(agent::Agent, input1, input2, inputs...) # 不强制Nothing
            # 使用多个input参数，避免被派发到自身
            put!(agent, (input1, input2, inputs...))
        end
    
        "针对「可变长参数」的多项输入（派发到最上方put）" # 不强制inputs的类型
        function put!(agent::Agent, inputs::Union{Vector,Tuple}) # 不强制Nothing
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
            # @info "Agent catched: $line" # 【20230710 15:59:50】Game接收正常
            # try # 【20230710 16:22:45】操作捕捉测试正常
                operation::Operation = getRegister(agent).operation_catch(line)
                if !isempty(operation)
                    # @show operation operation.parameters # 【20230710 16:51:15】参数检验（OpenNARS）正常
                    @info "EXE #$(agent.stats.total_initiative_operations): $operation at line「$line」"
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

        """更新智能体本身
        返回：更新中获取到的所有感知
        """
        function update!(agent::Agent, sense_targets...; sense_targets_kw...)::Vector{Perception}
            perceptions::Vector{Perception} = update_sensors!(agent, sense_targets...; sense_targets_kw...) # 更新感知器
            update_goals!(agent) # 更新目标
            cycle!(agent) # 推理步进
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
                - 前两个参数固定为：收集器，Agent自身
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
        function put!(agent::Agent, goal::Goal, is_negative::Bool)
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
            # @info "registering..." # 【20230710 17:18:54】注册测试正常
            s ∉ agent.sensors && push!(agent.sensors, s) # 考虑把sensors当做一个集合？
        end

        "添加感知"
        function put!(agent::Agent, np::Perception)
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

        """返回所有操作的迭代器（不论存量是否为零）"""
        operations_itor(agent::Agent) = (
            (op, num)
            for (op,num) in agent.operations
        )

        "返回缓存的操作数量（值的总和）"
        numStoredOperations(agent::Agent)::Integer = agent.operations |> values |> sum

        "添加无意识操作（用Operation重载put!，对应PyNEI的put_unconscious_operation）入Program" # TODO：是否可以将其和put!整合到一起？（put一个操作）
        function put!(agent::Agent, op::Operation)
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
                # @info "Registered new operation as key: $operation"
            end
        end

        "消耗/减少操作 = 存储相反数"
        function reduce!(agent::Agent, operation::Operation, num::Integer=1)
            store!(agent, operation, -num)
        end

        "清除已存储的操作"
        function clear_stored_operations(agent::Agent)
            for key in keys(agent.operations)
                agent.operations[key] = 0
            end
        end

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
    end
end

end