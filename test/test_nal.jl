push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI.NAL

"================Test for NAL================" |> println

# 词项

@show self::AbstractAtom = TERM_SELF
@assert self |> nameof == "SELF"
@assert self isa AtomInstance
@assert "$self" == "{SELF}"

good::Term = Term"[good]"
@assert good |> typeof == AtomProperty
