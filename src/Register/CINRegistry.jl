"""
现有库所支持之CIN(Computer Implement of NARS)的注册器

注册在目前接口中可用的CIN类型
- OpenNARS(Java)
- ONA(C/C++)
- Python(Python)
- Junars(Julia)【WIP】
- 【未来还可更多】
"""
module CINRegistry

using ...Support

using Reexport

using ...Embodied.NARSElements # 在函数实现中要使用/对接到抽象元素

# 使用「@reexport」是为以下模块之函数添加方法
@reexport using ...Interface.CIN # 对接CIN接口
@reexport using ..Templates # 导入模板

# 「具体CIN注册」交给下面的jl：抽象接口与具体注册分离
"几个对应的「CIN实现」注册（兼注册CIN类型）"
CIN_REGISTER_DICT::Dict = include("CINRegistry/register.jl")
#= 功能：定义CIN注册字典，存储与「具体CIN实现」的所有信息
- CIN_REGISTER_DICT：NARSType→CINRegister
注：使用include，相当于返回其文件中的所有代码
- 故可以在该文件中返回一个Dict，自然相当于把此Dict赋值给变量CIN_REGISTER_DICT
- 从而便于管理变量名（无需分散在两个文件中）
=#

#= 注：不把以下代码放到templates.jl中，因为：
- Program要用到NARSType
- 以下代码要等Register注册
- Register要等Program类声明
因此不能放在一个文件中
=#
begin "依赖注册表的方法（添加一系列方法）"

    """
    检验NARSType的有效性：是否已被注册

    - 📌访问字典键值信息，用方法而不用属性（否则报错：#undef的「access to undefined reference」）
    """
    Base.isvalid(nars_type::NARSType)::Bool = nars_type ∈ keys(CIN_REGISTER_DICT)

    "Type→Register（依赖字典）"
    Base.convert(
        ::Core.Type{CINRegister}, type::NARSType
    )::CINRegister = CIN_REGISTER_DICT[type]

    "名称→Type→Register（依赖字典）"
    Base.convert(
        ::Core.Type{CINRegister}, 
        type_name::String
    )::CINRegister = CIN_REGISTER_DICT[NARSType(type_name)]

    "Program→Type：复现PyNEI中CINProgram的「type」属性"
    Base.convert(
        ::Core.Type{NARSType}, 
        program::CINProgram
    )::NARSType = program.type

    "Type→Program类" # 尽可能用Julia原装方法
    Base.convert(
        ::Core.Type{Core.Type}, 
        nars_type::NARSType
    )::Core.Type = CIN_REGISTER_DICT[nars_type].program_type
    
    """
    Type→Program：复现PyNEI中的CINProgram.fromType函数（重载外部构造方法）
    - 📌「Core.Type{CINProgram}」会过于精确而报错
        - 报错信息：Cannot `convert` an object of type Type{CINProgram_OpenNARS} to an object of type Type{CINProgram}
    """
    CIN.CINProgram(nars_type::NARSType, args...; kwargs...)::CINProgram = 
        Base.convert( # 获得构造方法
            Core.Type, nars_type
        )( # 调用构造方法
            nars_type,  # 目前第一个参数是NARSType
            args...; kwargs...
        )

    "Program→Type→Register（复现Python中各种「获取模板」的功能）" # 尽可能用Julia原装方法
    Base.convert(
        ::Core.Type{CINRegister}, 
        program::CINProgram
    )::CINRegister = CIN_REGISTER_DICT[convert(NARSType, program)]

    "派发NARSType做构造方法"
    Templates.CINRegister(nars_type::NARSType) = Base.convert(CINRegister, nars_type)

    "派发Program做构造方法"
    Templates.CINRegister(program::CINProgram) = Base.convert(CINRegister, program)
end

begin "从CIN解耦出来的方法"

    "实现CIN的方法声明"
    CIN.getRegister(program::CINProgram)::CINRegister = convert(CINRegister, program) # 通过convert实现
    
end

end
