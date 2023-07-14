"""「NARS环境」：对接Agent与游戏文件
- 🎯减少「Agent与游戏环境间对接」所需要的代码量
    - 尽可能减少「代码对接」对游戏源码的修改量
- 主要用法
    1. 游戏复合一个Environment对象
        1. Game向Environment注册Agent
            - 由Environment自动创建新Agent
            - Game创建Agent，并与Environment对接
        2. 
    2. 游戏在对应事件中，
        1. 游戏信息@Game → Perception ⇒ Environment ⇒ Agent
        2. Operation@Agent ⇒ Environment ⇒ 响应@Game
"""
module NARSEnvironment

# 导入
using ..NARSElements
using ..NARSAgent

import ..NARSAgent: isAlive # 重名覆盖

# 导出
export Environment
export hasAgent, isAlive, getAgent
export register_agent!, create_agent!, activate_all_agents!
export discord_agent, discord_all_agents!
export agent_babble!, agent_praise!, agent_punish!, agent_put!, agent_register!, agent_update!
export iterate_operations


begin "Environment"

    """NARS环境
    - 使用泛型指定Agent的标识符
    """
    struct Environment{Identifier}

        """存储已注册的「游戏实体」（NARS智能体）
        - 使用Symbol作为「智能体」的索引
            - 例：使用Symbol「:red」「:black」标记中国象棋的「红方」「黑方」
        """
        agents::Dict{Identifier, Agent}

        # 📝带泛型类的构造函数：函数名+new 均带泛型指示
        function Environment{Identifier}() where Identifier
            new{Identifier}( # 泛型参数需要注册
                Dict{Identifier, Agent}(), # 空字典
            )
        end
    end

    # Agent注册 #

    """获取「是否有Agent」
    """ # 📝Julia中处理「使用泛型的类型」需要声明「泛型类{模板类型}」+「where 模板类型」
    function hasAgent(env::Environment{Identifier}, identifier::Identifier)::Bool where Identifier
        return identifier in keys(env.agents)
    end

    """是否存活⇔是否有任意Agent存活
    """
    function isAlive(env::Environment)
        return any(env.agents |> values .|> isAlive)
    end

    """根据符号名获取Agent（未知是否有）
    - 「已知是否有」版本：env.agents[i]
    """
    function getAgent(env::Environment{Identifier}, i::Identifier)::Union{Agent,Nothing} where Identifier
        hasAgent(env, i) && return env.agents[i]
        return nothing
    end

    """注册Agent（向环境中添加智能体）
    """
    function register_agent!(env::Environment{Identifier}, i::Identifier, agent::Agent) where Identifier
        push!(env.agents, i => agent) # 若「重名」会自动覆盖掉
        # @info "Agent $agent at :$i registered!" # 【20230710 15:56:04】测试正常
    end

    """创建并自动注册Agent
    """
    function create_agent!(env::Environment{Identifier}, i::Identifier, args...; kwargs...)::Agent where Identifier
        agent::Agent = Agent(args...; kwargs...) # 传参注册
        agent_register!(env, i, agent) # 注册
        return agent # 返回
    end

    """激活所有Agent
    """
    function activate_all_agents!(env::Environment{Identifier}) where Identifier
        for agent in values(env.agents)
            !isAlive(agent) && activate!(agent)
        end
    end

    """终止单个Agent
    """
    function discord_agent(env::Environment{Identifier}, i::Identifier)::Union{Agent,Nothing} where Identifier
        hasAgent(env, i) && discord_agent(env, i, env.agents[i])
    end

    "已知Agent版本"
    function discord_agent(env::Environment{Identifier}, i::Identifier, agent::Agent) where Identifier
        terminate!(agent) # 终止Agent
        delete!(env.agents, i) # 删除
    end

    """终止所有Agent
    """
    function discord_all_agents!(env::Environment{Identifier}) where Identifier
        for (i::Identifier, agent::Agent) in env.agents
            isAlive(agent) && discord_agent(env, i, agent)
        end
    end

    # 传输指令：对接Agent的各类方法 #

    begin "update"
        
        """更新某个Agent
        """
        function agent_update!(
            env::Environment{Identifier},
            i::Identifier, 
            args...;
            kwargs...
            ) where Identifier
            hasAgent(env, i) && agent_update!(env, env.agents[i], args...; kwargs...)
        end

        "已知Agent版本"
        function agent_update!(
            env::Environment{Identifier}, 
            agent::Agent, 
            args...;
            kwargs...
            ) where Identifier
            update!(agent, args...; kwargs...)
        end

        "广播版本（无指定索引/Agent）"
        function agent_update!(
            env::Environment{Identifier}, 
            args...;
            kwargs...
            ) where Identifier
            for agent::Agent in values(env.agents)
                agent_update!(env, agent, args...; kwargs...)
            end
        end
    end

    begin "put"
        
        Putable::Type = Union{Operation, Perception, Goal, String}

        """对某个Agent输送感知/操作（无意识操作）/目标
        """
        function agent_put!(
            env::Environment{Identifier},
            i::Identifier, 
            thing::Putable,
            args...
            ) where Identifier
            hasAgent(env, i) && agent_put!(env, env.agents[i], thing, args...)
        end

        "已知Agent版本"
        function agent_put!(
            env::Environment{Identifier}, 
            agent::Agent, 
            thing::Putable,
            args...
            ) where Identifier
            put!(agent, thing, args...)
        end

        "广播版本（无指定索引/Agent）"
        function agent_put!(
            env::Environment{Identifier}, 
            thing::Putable,
            args...
            ) where Identifier
            for agent::Agent in values(env.agents)
                agent_put!(env, agent, thing, args...)
            end
        end
    end

    begin "register"
        
        Registerable::Type = Union{Operation, Goal, Sensor}

        """对某个Agent进行注册
        """
        function agent_register!(
            env::Environment{Identifier},
            i::Identifier,
            thing::Registerable,
            args...
            ) where Identifier
            hasAgent(env, i) && agent_register!(env, env.agents[i], thing, args...)
        end

        "已知Agent版本"
        function agent_register!(
            env::Environment{Identifier},
            agent::Agent,
            thing::Registerable,
            args...
            ) where Identifier
            register!(agent, thing, args...)
        end

        "广播版本（无指定索引/Agent）"
        function agent_register!(
            env::Environment{Identifier}, 
            thing::Registerable,
            args...
            ) where Identifier
            for agent::Agent in values(env.agents)
                agent_register!(env, agent, thing, args...)
            end
        end

        begin "babble"

            """Babble其中的Agent
            """
            function agent_babble!(
                env::Environment{Identifier},
                i::Identifier,
                perceptions::Vector{Perception},
                ) where Identifier
                hasAgent(env, i) && agent_babble!(env, env.agents[i], perceptions)
            end

            "已知Agent版本"
            function agent_babble!(
                env::Environment{Identifier},
                agent::Agent,
                perceptions::Vector{Perception},
                ) where Identifier
                babble!(agent, perceptions)
            end

            "广播版本（无指定索引/Agent）"
            function agent_babble!(
                env::Environment,
                perceptions::Vector{Perception},
            )
                return vcat([ # （需要返回操作序列）遍历所有再连接
                    agent_babble!(env, agent, perceptions) # 返回操作数组
                    for agent::Agent in values(env.agents)
                ]...)
            end
        end
    end

    # Agent目标评价 #

    begin "praise"
        
        """奖励其中的Agent
        """
        function agent_praise!(
            env::Environment{Identifier},
            i::Identifier,
            goal::Goal,
            ) where Identifier
            hasAgent(env, i) && agent_praise!(env, env.agents[i], goal)
        end

        "已知Agent版本"
        function agent_praise!(
            env::Environment{Identifier},
            agent::Agent,
            goal::Goal,
            ) where Identifier
            praise!(agent, goal)
        end

        "广播版本（无指定索引/Agent）"
        function agent_praise!(
            env::Environment,
            goal::Goal,
        )
            for agent::Agent in values(env.agents)
                agent_praise!(env, agent, goal) # 返回操作数组
            end
        end
    end

    begin "punish"

        """惩罚其中的Agent
        """
        function agent_punish!(
            env::Environment{Identifier},
            i::Identifier,
            goal::Goal,
            ) where Identifier
            hasAgent(env, i) && agent_punish!(env, env.agents[i], goal)
        end

        "已知Agent版本"
        function agent_punish!(
            env::Environment{Identifier},
            agent::Agent,
            goal::Goal,
            ) where Identifier
            punish!(agent, goal)
        end

        "广播版本（无指定索引/Agent）"
        function agent_punish!(
            env::Environment,
            goal::Goal,
        )
            for agent::Agent in values(env.agents)
                agent_punish!(env, agent, goal) # 返回操作数组
            end
        end
    end

    import IterTools: chain # 链式迭代

    """遍历获取所有Agent的所有操作
    - 返回一个迭代器（不一定是Generator）
    - 遍历其中所有Agent
        - 再遍历每个Agent的operations
        - 返回(i, agent, operation, num)
    """
    function iterate_operations(
        env::Environment{Identifier}
    ) where Identifier
        return chain([
            (
                (i, agent, operation, num)
                for (operation::Operation,num) in agent.operations
            )
            for (i::Identifier,agent::Agent) in env.agents
        ]...)
    end
end

end