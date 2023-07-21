push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using Test

using JuNEI
using JuNEI.Utils

"================Test for Environment================" |> println

@testset "Environment" begin

    # 测试 构造方法 #

    "空Agent"
    blank_agent::Agent = Agent(
        NARSType"Junars", # 占位符
        ""
    )

    @show e = Environment()
    @show e0 = Environment{Symbol}()
    @show e1 = Environment{Symbol}(Dict{Symbol,Agent}(
        :a => blank_agent,
        :b => blank_agent,
    ))
    @show e2 = Environment{Symbol}([
        :a => blank_agent
        :b => blank_agent
    ])
    @show e3 = Environment{Symbol}(
        :a => blank_agent,
        :b => blank_agent,
    )
    @test e == e0 # 两种构造方法等价
    @test e1 == e2 == e3 # 几种构造方法等价

    # 测试 Agent(WIP) #
    
end