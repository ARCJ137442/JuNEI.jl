push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using Test

using JuNEI.NAL

"================Test for NAL(WIP)================" |> println

# 词项

@testset "NAL(WIP)" begin
    @show self::AbstractAtom = TERM_SELF
    @test self |> nameof == "SELF"
    @test self isa AtomInstance
    @test "$self" == "{SELF}"

    good::Term = Term"[good]"
    @test good |> typeof == AtomProperty    
end
