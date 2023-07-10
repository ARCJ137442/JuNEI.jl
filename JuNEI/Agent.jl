"NARS智能体的统计（可变对象）"
mutable struct NARSAgent_Stats
    total_sense_inputs::Unsigned
    total_initiative_operations::Unsigned
    total_unconscious_operations::Unsigned
end

"默认构造函数：产生空值"
NARSAgent_Stats() = NARSAgent_Stats(0,0,0)

"复制一个统计对象（struct不会默认派发到copy方法）"
copy(stats::NARSAgent_Stats) = NARSAgent_Stats(
    stats.total_sense_inputs,
    stats.total_initiative_operations,
    stats.total_unconscious_operations,
)

begin "Agent"

    """从CIN到交互的示例2：NARS智能体（无需可变）
    - 🎯面向游戏调用
    - 📄内置NARSAgent
    - 🔬展示「如何封装CIN」的高级例子
    """
    struct NARSAgent

        # CIN
        program::NARSProgram # 一个Agent，一个Program

        # 目标
        goals::Vector{Tuple{NARSGoal,Bool}} # Goal, is_negative

        # 感知
        sensors::Vector{NARSSensor}

        # 操作
        operations::Dict{NARSOperation, Unsigned}

        # 统计
        stats::NARSAgent_Stats

        # 运行

        "总体调控NARS智能体的「推理频率」，对应PyNEI的「inference_cycle_frequency」"
        cycle_speed::Integer

        """背景本能系统
        对应关系：Babble⇔Background Inheriant System
        - 类型：智能体+感知→操作
            - 格式：function (agent::NARSAgent, perceptions::Vector{NARSPerception})::Vector{NARSOperation}
        - 功能：在NARSAgent「尚未能自主决策」时，调用该「必定能决策」的系统
        - 默认情况：随机选取
        """
        babble_hook::Function # 是否要为了「让其可变」而让整个类mutable？

        "正常构造函数"
        NARSAgent(
            type::NARSType, 
            executable_path::String; # 内部构造函数可以接受关键字参数
            cycle_speed::Integer=1,
            babble_hook::Function=babble, # 占位符
            ) = begin
            
            # 先构造自身
            agent = new(
                NARSCmdline(
                    type, # 传入Agent
                    executable_path, # 可执行文件路径
                    identity, # 占位符
                ),
                Tuple{NARSGoal,Bool}[], # 空值
                NARSSensor[], # 空值
                Dict{NARSOperation, Unsigned}(),
                NARSAgent_Stats(), # 空值（注意：结构体的new不支持关键字参数，）
                cycle_speed, # 强行使用关键字参数则报错：「syntax: "new" does not accept keyword arguments around 」
                babble_hook,
            )
            
            # 闭包传输（需要先定义agent）
            out_hook!(agent.program, line -> use_hook(agent, line))

            return agent
        end

        # 需要在内部构造函数中使用，在外部则只能访问到上面那个构造函数
        "复制一份副本（所有变量，包括统计），但不启动"
        NARSAgent(agent::NARSAgent) = new(
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
        copy(agent::NARSAgent)::NARSAgent = NARSAgent(agent)
        similar(agent::NARSAgent)::NARSAgent = copy(agent)

        #= Program继承 =#

        "同Program"
        getNARSType(agent::NARSAgent)::NARSType = getNARSType(agent.program)
        
        "同Program"
        getRegister(agent::NARSAgent)::CINRegister = getRegister(agent.program)
    
        "同Program"
        has_hook(agent::NARSAgent)::Bool = has_hook(agent.program)
    
        "同Program"
        use_hook(agent::NARSAgent, content::String) = use_hook(agent.program, content)
        
        "同Program"
        out_hook!(agent::NARSAgent, newHook::Union{Function,Nothing})::Union{Function,Nothing} = out_hook!(agent.program, newHook)

        "同Program"
        isAlive(agent::NARSAgent) = isAlive(agent.program)
        
        "同Program"
        terminate!(agent::NARSAgent) = terminate!(agent.program)
        
        "同Program（使用参数展开，让Program自行派发）"
        put!(agent::NARSAgent, input::String) = put!(agent.program, input)

        "针对「可变长参数」的多项输入（派发到最上方put）" # 不强制inputs的类型
        function put!(agent::NARSAgent, input1, input2, inputs...) # 不强制Nothing
            # 使用多个input参数，避免被派发到自身
            put!(agent, (input1, input2, inputs...))
        end
    
        "针对「可变长参数」的多项输入（派发到最上方put）" # 不强制inputs的类型
        function put!(agent::NARSAgent, inputs::Union{Vector,Tuple}) # 不强制Nothing
            # 注意：Julia可变长参数存储在Tuple而非Vector中
            for input ∈ inputs
                # @show input typeof(input)
                put!(agent, input)
            end
        end

        "同Program"
        cycle!(agent::NARSAgent, steps::Integer) = cycle!(agent.program, steps)

        "重载默认值：使用「cycle_speed」属性"
        cycle!(agent::NARSAgent) = cycle!(agent.program, agent.cycle_speed)

        #= 控制 =#

        "默认输出钩子（包括agent对象「自身」）"
        function use_hook(agent::NARSAgent, line::String)
            # @info "Agent catched: $line" # 【20230710 15:59:50】Game接收正常
            # try # 【20230710 16:22:45】操作捕捉测试正常
                operation::NARSOperation = getRegister(agent).operation_catch(line)
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
        function activate!(agent::NARSAgent)
            launch!(agent.program) # 启动CIN程序
        end

        """更新智能体本身
        返回：更新中获取到的所有感知
        """
        function update!(agent::NARSAgent, sense_targets...; sense_targets_kw...)::Vector{NARSPerception}
            perceptions::Vector{NARSPerception} = update_sensors!(agent, sense_targets...; sense_targets_kw...) # 更新感知器
            update_goals!(agent) # 更新目标
            cycle!(agent) # 推理步进
            return perceptions
        end

        "复现PyNEI中的「update_sensors」"
        function update_sensors!(agent::NARSAgent, sense_targets...; sense_targets_kw...)
            # 收集所有感知
            perceptions::Vector{NARSPerception} = collect_all_perceptions(agent, sense_targets...; sense_targets_kw...)
            # 加入感知
            for perception in perceptions
                # 加入命令
                put!(agent, perception)
                # 添加统计
                agent.stats.total_sense_inputs += 1
            end
            return perceptions
        end

        "从感知器中获取所有「NARS感知」，并存放到指定「收集器」中"
        function collect_all_perceptions(agent::NARSAgent, sense_targets...; sense_targets_kw...)::Vector{NARSPerception}
            # 建立收集器
            result::Vector{NARSPerception} = NARSPerception[]
            # 收集感知
            for sensor!::NARSSensor in agent.sensors
                 # （直接调用无需检测）传参(前两个参数固定为：Agent自身，收集器)
                sensor!(agent, result, sense_targets...; sense_targets_kw...)
            end
            # 返回感知
            # @show result
            return result
        end

        "更新智能体目标"
        function update_goals!(agent::NARSAgent)
            for (goal::NARSGoal, is_negative::Bool) in agent.goals
                put!(agent, goal, is_negative)
            end
        end

        #= 输入+调用模板（没必要内置到NARSProgram中） =#
        
        # 目标
        
        "返回所有已注册的目标（无「是否负向」，生成器）"
        goals(agent::NARSAgent)::Base.Generator = (
            goal # 只保留目标
            for (goal,_) in agent.goals
        )

        "添加目标（派发NARSGoal）入Program"
        function put!(agent::NARSAgent, goal::NARSGoal, is_negative::Bool)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).put_goal(goal, is_negative)
            )
        end

        "注册目标：将目标存入"
        function register!(agent::NARSAgent, goal::NARSGoal, is_negative::Bool=false)
            push!(agent.goals, (goal, is_negative))
        end
        
        "奖励目标"
        function praise!(agent::NARSAgent, goal::NARSGoal)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).praise(goal)
            )
        end
        
        "惩罚目标"
        function punish!(agent::NARSAgent, goal::NARSGoal) # 不强制Nothing
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).punish(goal)
            )
        end
        
        # 感知

        "添加感知器"
        function register!(agent::NARSAgent, ns::NARSSensor)
            # @info "registering..." # 【20230710 17:18:54】注册测试正常
            ns ∉ agent.sensors && push!(agent.sensors, ns) # 考虑把sensors当做一个集合？
        end

        "添加感知"
        function put!(agent::NARSAgent, np::NARSPerception)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).sense(np)
            )
        end

        # 操作

        "返回所有已注册的操作（类列表形式，可collect）"
        getOperations(agent::NARSAgent)::Base.KeySet = keys(agent.operations)

        "返回缓存的操作数量（值的总和）"
        numStoredOperations(agent::NARSAgent)::Integer = agent.operations |> values |> sum

        "添加无意识操作（用NARSOperation重载put!，对应PyNEI的put_unconscious_operation）入Program" # TODO：是否可以将其和put!整合到一起？（put一个操作）
        function put!(agent::NARSAgent, op::NARSOperation)
            put!(
                agent.program,
                getRegister(
                    agent # 从模板处获取
                ).babble(op) # 注意：无需判断了，只需要「输入无效」就能实现同样效果
            )
        end
        
        "添加「操作注册」入Program：让NARS「知道」有这个操作（对应PyNEI的register_basic_operation）"
        function register!(agent::NARSAgent, op::NARSOperation)
            # 置入语句
            @info "register operation $op"
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
        function remind_operations(agent::NARSAgent)
            for operation in agent.operations
                register!(agent, operation)
            end
        end

        "存储操作"
        function register!(agent::NARSAgent, operation::NARSOperation, num::Integer=1)
            if haskey(agent.operations, operation)
                agent.operations[operation] += num
            else
                agent.operations[operation] = num
                # @info "Registered new operation as key: $operation"
            end
        end

        "消耗/减少操作 = 存储相反数"
        function reduce!(agent::NARSAgent, operation::NARSOperation, num::Integer=1)
            register!(agent, operation, -num)
        end

        "清除已存储的操作"
        function clear_stored_operations(agent::NARSAgent)
            for key in keys(agent.operations)
                agent.operations[key] = 0
            end
        end

        "处理CIN输出的操作"
        function hook_operation!(agent::NARSAgent, operation::NARSOperation)
            # 存储操作
            register!(agent, operation)
            # 添加统计
            agent.stats.total_initiative_operations += 1
        end
        
        "调用「背景本能系统」：无意识操作"
        function babble!(agent::NARSAgent, perceptions::Vector{NARSPerception})::Vector{NARSOperation}
            # 从「背景本能系统」中获取操作
            operations::Vector{NARSOperation} = agent.babble_hook(agent, perceptions)
            for operation in operations
                # 添加无意识操作
                put!(agent, operation)
                # 存储操作 （绕过统计）
                register!(agent, operation)
                # 添加统计
                agent.stats.total_unconscious_operations += 1
            end
            return operations
        end

        "默认babble：随机选取已注册的操作"
        function babble(agent::NARSAgent, perceptions::Vector{NARSPerception})::Vector{NARSOperation}
            # 获取所有可用操作，使用rand随机选取
            operations::Vector{NARSOperation} = agent |> getOperations |> collect
            return (
                isempty(operations) ? 
                operations : 
                NARSOperation[
                    operations |> rand
                ]
            )
        end
    end
end