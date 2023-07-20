"""
一个简单的游戏示例：越障游戏
- 目标：（无尽）越过游戏内在角色之前的障碍
- 感知：（实时）对障碍高度、离玩家距离的感知
- 操作：跳跃
- 知识：根据「离障碍的远近」与「障碍的高度」做跳跃
    - CheatPoint（本能系统の解）：在障碍「足够近」时自动跳跃

现况：
- 
"""

push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI

begin "实用工具"
    
    "清屏"
    cls() = `cmd /c cls` |> run # 直接使用「/c」参数在当前界面运行指令
    
end

begin "游戏逻辑"

    """
    游戏本体

    主要逻辑：
    - 玩家固定在(0,y)坐标（显示上在屏幕中央）
    - 根据obstacle_RNG生成下一个障碍
        - `next_obstacle = rand.(obstacle_RNG)`
    - 障碍没到卷轴宽度时，相当于「冷却时间」

    """
    @wrap_env_link mutable struct LeapGame

        const scroll_range::Integer # 卷轴宽度（一半，显示的完整宽度为2scroll_range+1）
        const obstacle_RNG::NTuple{3} # 不变的生成器（三个可迭代对象，生成「(x,y,height)」）
        const player_gravity::Integer # 重力速率
        const player_jump_strength::Integer # 跳跃能力
        const FPS::Integer # 游戏速度（帧率）

        player_y::Integer # 玩家y坐标
        obstacle_x::Integer # 障碍的x坐标
        obstacle_y_range::AbstractRange # 障碍y坐标的范围
        
        last_input::String # 上一个输入信号
        last_render::String # 上一个渲染（用于减少重复渲染）

        "构造函数：设置其中的常量"
        function LeapGame(
            scroll_range::Integer,
            obstacle_RNG::NTuple{3},
            player_gravity::Integer,
            player_jump_strength::Integer,
            FPS::Integer = 20,
        )
            return new(
                scroll_range,
                obstacle_RNG,
                player_gravity,
                player_jump_strength,
                FPS,
                0, # 玩家y坐标
                0, 0:0, # 障碍坐标
                "", # 上一输入
                "", # 上次渲染
            )
        end
    end
    @generate_gset_env_link LeapGame

    "启动游戏"
    function launch!(game::LeapGame)
        # 异步请求输入
        @async while true
            game.last_input = request_input(game)
        end
        # 开始游戏主程序
        while true
            update!(game)
            sleep(1/game.FPS)
        end
    end

    "游戏的单次循环"
    function update!(game::LeapGame)
        update_obstacles!(game) # 障碍先移动（实现「玩家在障碍下起跳」的效果）
        update_character!(game, game.last_input) # 玩家再移动
        !isempty(game.last_input) && (game.last_input = "") # 有输入⇒重置输入
        response(game) # 发送反馈
        render(game) # 渲染
    end

    """
    重置游戏障碍物（重新随机生成）
    """
    function reset_obstacles!(game::LeapGame)
        x, y, h = rand.(game.obstacle_RNG)
        game.obstacle_x = x
        game.obstacle_y_range = y:(y+h)
    end

    """
    更新障碍物的位置或状态
    """
    function update_obstacles!(game::LeapGame)
        
        # 障碍移动（减过去，试探，撞了⇒加回来）
        game.obstacle_x -= 1 # x坐标固定递减
        check_collision(game) && (game.obstacle_x += 1) # 若碰撞了，则不动

        # 显示范围在超出后方的，消失&重置
        game.obstacle_x < -game.scroll_range && reset_obstacles!(game)
    end
    
    """
    处理角色状态更新
    根据用户输入和游戏规则，更新角色的位置、高度和状态
    """
    function update_character!(game::LeapGame, user_input)
        if !isempty(user_input) && game.player_y == 0 # 输入非空，且在地上
            game.player_y += game.player_jump_strength
        else
            # 处理重力
            new_player_y = game.player_y - game.player_gravity
            # 若将碰撞，则不下降 && 单次迭代重力超过，且原本不在地上：强制在地上
            if new_player_y ≥ 0 && !check_collision(game, 0, new_player_y)
                game.player_y = new_player_y
            end
        end
    end

    """
    检查指定坐标与障碍物的碰撞
    - 返回：「是否发生碰撞」
    """
    function check_collision(
        game::LeapGame, 
        x::Integer = 0,
        y::Integer = game.player_y # 默认为游戏的玩家坐标
        )::Bool
        return (
            x == game.obstacle_x && # 障碍x坐标可变
            y in game.obstacle_y_range # 在一定高度范围内
        )
    end

    """
    游戏的（显示）卷轴长度
    """
    scroll_length(game::LeapGame)::Integer = 2game.scroll_range + 1

    """
    游戏的（显示）卷轴高度
    - 经验上：默认为「玩家跳跃强度」的两倍
    """
    scroll_height(game::LeapGame)::Integer = 2game.player_jump_strength

    """
    渲染游戏界面
    使用终端输出函数打印字符画界面
    根据当前的游戏状态，将卷轴、角色和障碍物渲染到字符画界面上
    【20230716 20:00:18】TODO：需要实现「彩色显示」？
    """
    function render(game::LeapGame)
        render = ""
        # 获取（显示上的）卷轴长宽
        for y::Integer in (scroll_height(game)):-1:0 # 打印是从高到低
            # underline::Bool = y == 0
            for x::Integer in (-game.scroll_range):(game.scroll_range) # 从负到正
                if x == 0 && y == game.player_y
                    render *= "P"  # 角色用 "@" 表示
                    # printstyled("@"; bold=true, color=:light_blue, underline=underline)
                elseif check_collision(game, x, y)
                    render *= "#"  # 障碍物用 "#" 表示
                    # printstyled("#"; bold=true, color=:light_green, underline=underline)
                else
                    render *= " "  # 空白区域依「是否在地面上」用 " "/"_" 表示
                    # printstyled(" "; underline=underline)
                end
            end
            render *= "\n"
        end
        # 若需要更新，则打印
        if render ≠ game.last_render
            cls()
            print(render) # 一次性打印
            game.last_render = render
            # 打印地面：使用「带格式字符」反色打印
            printstyled(
                " " ^ scroll_length(game) * "\n"; 
                reverse=true # 反色「从黑到白」
                )
        end
    end
end

begin "接口"

    """
    初始化游戏
    """
    function init!(game::LeapGame)
        reset_obstacles!(game) # 重新生成障碍
    end

    """
    请求输入
    - 对接：遍历环境的所有操作
    """
    function request_input(game::LeapGame)
        # readline(stdin) # 中断命令行，等待回车
        # "1" # 只要回车，就算做「有输入」

        # 遍历所有操作
        for (i, agent, op, n) in operations_itor(game.env_link)
            if n > 0 && op == Operation"up"
                return nameof(op) # 有响应
                @info "agent operation..."
            end
        end
        # 无操作：babble⇒延时⇒返回空值
        agent_babble(game.env_link)
        @info "agent babble..."
        sleep(1)
        return ""
    end

    """
    反馈
    【20230716 10:07:58】实时游戏中是否需要？
    """
    function response(game::LeapGame)
        @show 1
        @soft_isnothing_property(game.env_link) && isAlive(game.env_link) && update!(game.env_link) # 环境更新
    end

end

begin "NARS环境实现"

    "所有合法操作之名"
    const OPERATION_NAMES::Vector{String} = [
        "up"
    ]

    "（对接）"
    function agent_sensor_hook!(collector::Vector{Perception}, agent::Agent, game::LeapGame)
        @show collector agent game
        # push!(collector, Perception"test"other)
        # 暂时不使用感知：游戏只有对「操作之后」的反馈，而没有「实时状态」的更新
    end

    "（对接）初始化Environment：注册Agent（只初始化一次）"
    function init_environment!(
        game::LeapGame, 
        type_name::Union{String,Nothing}=nothing, 
        executable_path::Union{String,Nothing}=nothing, 
    )
        # 构造对象，注册Agent
        game.env_link = Environment{Symbol}(
            :nars => Agent(
                NARSType(isnothing(type_name) ? inputType() : type_name),
                isnothing(executable_path) ? input() : executable_path;
                # babble_hook = agent_babble_hook # TODO
            )
        )
        # 批量置入目标
        for goalname::String in [
            "good" # 所谓「达到目的」
            "valid" # 有效性
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
            SensorBasic( # 似乎可以变化？
                agent_sensor_hook!
            )
        )
        # 批量注册操作
        for operation_name::AbstractString in OPERATION_NAMES
            agent_register!(
                game.env_link,
                Operation(operation_name)
            )
        end
        # 启动
        activate_all_agents!(game.env_link)
    end
end

# 游戏入口

game::LeapGame = LeapGame(
    10, # 卷轴宽度
    (10:15, 0:2, 1:3),
    1, # 重力
    4, # 跳跃高度
)

init_environment!(game, ARGS...) # 支持参数导入

init!(game)

launch!(game)