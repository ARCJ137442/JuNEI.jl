push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI

begin "实用工具"
    
    "清屏"
    cls() = `cmd /c cls` |> run # 直接使用「/c」参数在当前界面运行指令

end

begin "游戏逻辑"

    "游戏本体（其中一局）"
    struct NavigateGame{PointType}
        target_coordinates::PointType
        current_coordinates::PointType
        direction_vec::Vector{AbstractString}

        env_link::Environment # 🆕对接代码之一
    end

    "曼哈顿距离"
    function ^(coordinate1, coordinate2)::Number
        abs.(coordinate1 .- coordinate2) |> sum
    end

    "欧氏距离²"
    function ^²(coordinate1, coordinate2)::Number
        ((coordinate1 .- coordinate2) .^ 2) |> sum
    end

    function calculate_square_euclid_distance(game::NavigateGame)::Number
        game.current_coordinates ^² game.target_coordinates
    end

    function calculate_manhattan_distance(game::NavigateGame)::Number
        game.current_coordinates ^ game.target_coordinates
    end

    "是否到达目标"
    function is_reached(game::NavigateGame)::Bool
        return all(game.target_coordinates .== game.current_coordinates)
    end

    "评估坐标变化"
    function evaluate_coordinate_change(game::NavigateGame, move_vec)::Int8
        new_coordiante = game.current_coordinates .+ move_vec
        return sign(
            (new_coordiante^game.target_coordinates) - 
            (game.current_coordinates^game.target_coordinates)
        )
    end

    "字符串包含"
    (a::AbstractString) ⊂ (s::AbstractString) = contains(s,a)

    "遍历「先序索引」获得「操作名」对应的字符串"
    function indexin(direction_vec::Vector{AbstractString}, direction::AbstractString)::Unsigned
        for (i, direction_str) ∈ enumerate(direction_vec)
            if startswith(direction_str, direction)
                return i
            end
        end
        return 0 # Julia索引非零
    end

    "index_to_vec(3,3) = [0,1,0]"
    index_to_vec(index::Integer, ndim::Integer) = [
        (i == (index+1)÷2) ? (
            (index % 2 > 0) ? 1 : -1
        ) : 0
        for i in 1:ndim
    ]

    "获取位移向量"
    function get_move_vec(game::NavigateGame, direction::String)
        isempty(direction) && return nothing
        index::Unsigned = indexin(game.direction_vec, direction) # 注意：Julia的「索引」从一开始，就是「序数」
        if index > 0
            move_vec = index_to_vec(index, length(game.direction_vec)÷2)
            return move_vec
        end
        nothing
    end

    "游戏内移动"
    function make_move!(game::NavigateGame, move_vec)
        # @info "move! $game $move_vec"
        game.current_coordinates .+= move_vec
    end

    "开启游戏"
    function play_game(game::NavigateGame)
        move_count::Unsigned = 0
        while true

            println("当前坐标：", game.current_coordinates)
            # distance = calculate_manhattan_distance(game)
            # println("离目标距离：", distance)

            if is_reached(game)
                game_end(game, move_count)
                move_count = 0
                break
            end
            
            print("请输入移动方向($(join(game.direction_vec, '/'))): ")
            move_direction = requestInput(game)
            move_vec = get_move_vec(game, strip(move_direction) |> String)
            # println("移动：$move_vec")

            !response(game, move_direction, move_vec) && continue

            make_move!(game, move_vec)
            move_count += 1

            println()
        end
    end
end

begin "接口"

    "（对接）请求输入"
    function requestInput(game::NavigateGame)::String
        # readline() # 直接读取命令行输入

        # 更新Agent
        agent_update!(game.env_link, game)

        result = ""
        
        # 遍历所有Agent，搜索其操作
        for (i, agent, operation, num) in operations_itor(game.env_link)
            # 获取到一个有效的信息
            if num > 0
                # @info "catched operation $operation at $i"
                result = operation.name
                clear_stored_operations(agent) # 使用后直接清除所有缓存操作（若一个个遍历，则频繁操作无法及时处理）
                sleep(0.25)
                # reduce!(agent, operation) # 使用，减少
                # # @show numStoredOperations(agent)
                # numStoredOperations(agent)>0 && sleep(0.1/numStoredOperations(agent))
                break
            end
        end
        
        # 若无/空：返回Babble
        if isnothing(result) || isempty(result)
            agent_babble!(game.env_link, Perception[]) # TODO 问题：BIS需要环境信息，但这里不能传入环境作为参数
            @show numStoredOperations(getAgent(game.env_link, :nars))
            # sleep(
            #     1 + ops / (time() - start_time) # 操作次数/总时间流逝（s）
            #     # 📝time()获取的是s而非ms
            # )
            # 不要返回：babble的时候，已经置入了操作
            # if isempty(babble_op) # 若还是空
            #     result = ""
            # else # 返回第一个操作的名字（不完全？）
            #     result =  babble_op[1] |> nameof
            # end
        end
        println(result) # 模拟AI「输入了操作」
        return result
    end

    "（对接）游戏反馈（返回：是否「执行移动」）"
    function response(game::NavigateGame, move_direction, move_vec)
        
        if isnothing(move_vec)
            if !isempty(move_direction) # 若非「空指令」导致
                println("无效输入！\n")
                # 若是「非空指令」导致（Agent输出了无效的操作），反馈「操作无效」
                agent_punish!(game.env_link, Goal"valid")
            end
            return false
        end

        d_distance_sign::Integer = evaluate_coordinate_change(game, move_vec)

        # 打印信息
        if d_distance_sign == 0
            println("距离没变！")
        else
            println("距离变$(d_distance_sign>0 ? '大' : '小')了！")
        end

        # 广播感知
        agent_put!(game.env_link, 
            Perception(
                "SELF", d_distance_sign == 0 ? "no_change" : 
                d_distance_sign>0 ? "farther" : "closer"
                )
            )
        # 提示「有效」
        agent_praise!(game.env_link, Goal"valid")

        return true
    end

    function game_end(game::NavigateGame, move_count)
        println("恭喜，已到达目标点！")
        println("目标点是：$(game.target_coordinates)")
        println("移动次数：$move_count")

        # NARS奖励
        agent_praise!(game.env_link, Goal"succeed")

        sleep(3) # 停下一段时间
        cls() # 清屏
    end

    "（对接）初始化游戏"
    function init_game(ndim::Integer, env::Environment)::NavigateGame
        NavigateGame{Vector{Integer}}(
            rand(ndim) .* 20 .- 10 .|> round .|> Integer, # 目标
            zeros(ndim), # 起点
            String[
                "up",
                "down",
                "left",
                "right",
                "front",
                "back",
            ][1:(ndim*2)],
            env # 对接：获得一个「NARS环境」的引用
        )
    end

end


begin "NARS环境实现"

    "附加常量：可与「游戏实例」独立"
    # 📝Julia无法像Python那样注释变量：报错「cannot document the following expression」
    NARS_ENV::Environment{Symbol} = Environment{Symbol}() # 注册以Symbol为索引的泛型
    
    """（对接）babble钩子 背景本能系统
    TODO：有限情况下的「感知」（需要game，但只能提供perception）
    """
    function agent_babble_hook(agent::Agent, perceptions::Vector{Perception})::Vector{Operation}
        global game # 【20230707 0:13:55 TODO】导入game不太可取，但迫于时限没办法
        # 概率随机游走
        if rand(1:5) == 1
            return babble(agent, perceptions)
        end
        # 返回「能让距离变小」的操作
        for operation in getOperations(agent)
            dir::String = nameof(operation)
            move_vec = get_move_vec(game, dir) # 可能会返回空值
            if !isnothing(move_vec) && evaluate_coordinate_change(game, move_vec) < 0
                return Operation[operation]
            end
        end
        return Operation[]
    end

    "（对接）"
    function agent_sensor_hook!(collector::Vector{Perception}, agent::Agent, game::NavigateGame)
        @show collector agent game
        # push!(collector, Perception"test"other)
        # 暂时不使用感知：游戏只有对「操作之后」的反馈，而没有「实时状态」的更新
    end

    "（对接）初始化Environment：注册Agent（只初始化一次）"
    function init_environment(
        game::NavigateGame, 
        type_name::Union{String,Nothing}=nothing, 
        executable_path::Union{String,Nothing}=nothing, 
    )
        # 注册Agent
        register_agent!(
            game.env_link,
            :nars,
            Agent(
                NARSType(isnothing(type_name) ? inputType() : type_name),
                isnothing(executable_path) ? input() : executable_path;
                babble_hook = agent_babble_hook
            )
        )
        # 批量置入目标
        for goalname::String in [
            "succeed"
            "closer" # 是否需要个「短期目标」辅助上面的「长期目标」仍存疑
            "valid"
            ]
            agent_register!(
                game.env_link,
                Goal(goalname),
                false # is_negative？？！
            )
        end
        # 批量注册感知器
        agent_register!(
            game.env_link,
            SensorBasic(
                agent_sensor_hook!
            )
        )
        # 批量注册操作
        for operation_name::AbstractString in game.direction_vec
            agent_register!(
                game.env_link,
                Operation(operation_name)
            )
        end
        # 启动
        activate_all_agents!(game.env_link)
    end
end

# 游戏开始
global game = nothing
global start_time = time()
while true
    # try
        global game = init_game(3, NARS_ENV)
        isempty(NARS_ENV.agents) && init_environment(game, ARGS...) # 支持参数导入
        play_game(game)
    # catch e
    #     @error e
    # end
end
