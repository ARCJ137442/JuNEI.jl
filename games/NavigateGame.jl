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
        readline() # 直接读取命令行输入
    end

    "（对接）游戏反馈（返回：是否「执行移动」）"
    function response(game::NavigateGame, move_direction, move_vec)
        
        if isnothing(move_vec)
            if !isempty(move_direction) # 若非「空指令」导致
                println("无效输入！\n")
                # 若是「非空指令」导致（Agent输出了无效的操作），反馈「操作无效」
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

        return true
    end

    function game_end(game::NavigateGame, move_count)
        println("恭喜，已到达目标点！")
        println("目标点是：$(game.target_coordinates)")
        println("移动次数：$move_count")
        sleep(3) # 停下一段时间
        cls() # 清屏
    end

    "初始化游戏"
    function init_game(ndim::Integer)::NavigateGame
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
        )
    end
end

# 游戏开始
global game = nothing
global start_time = time()
while true
    # try
        global game = init_game(3)
        play_game(game)
    # catch e
    #     @error e
    # end
end
