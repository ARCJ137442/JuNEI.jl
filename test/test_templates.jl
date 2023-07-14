push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

using JuNEI.NARSElements
using JuNEI.CIN

"================Test for CIN Templates================" |> println

# NARSType

@assert NARSType"Python" == NARSType("Python")
@assert "$(Base.convert(String, NARSType"OpenNARS"))" == "OpenNARS"

# 无效转换
@assert NARSType"ChatGPT" |> !isvalid # 未注册名

@assert CINRegister"Python".punish(Goal"good") == "({SELF} --> [good]). :|: %0.00;0.90%"
@assert CINRegister"Python".register(Operation"move_left") == "((*,{SELF}) --> move_left). :|:"

@assert raw"EXE: $1.00;0.99;1.00$ ^operation_EXE([])=null" |> CINRegister"OpenNARS".operation_catch == Operation"operation_EXE"
@assert raw"EXE ^operation_EXE executed with args" |> CINRegister"ONA".operation_catch == Operation"operation_EXE"
@assert raw"EXE: ^operation_EXE based on desirability: 0.9" |> CINRegister"Python".operation_catch == Operation"operation_EXE"
