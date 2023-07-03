"""现有库所支持之CIN(Computer Implement of NARS)的注册项
注册在目前接口中可用的CIN类型
- OpenNARS(Java)
- ONA(C/C++)
- Python(Python)
- 【未来还可更多】
"""

include("Elements.jl")

begin "NARSType"
    
    # 不适合用@enum
    """NARSType：已支持CIN类型
    """
    struct NARSType
        name::String
    end
        
    begin "转换用方法（名称，不需要字典）" # 实际上这相当于「第一行使用字符串」的表达式，但「无用到可以当注释」
        
        "NARS类型→名称"
        nameof(nars_type::NARSType)::String = nars_type.name
        string(nars_type::NARSType)::String = nameof(nars_type)
        Base.convert(::Core.Type{String}, nars_type::NARSType) = nameof(nars_type)

        "名称→NARS类型"
        Base.convert(::Core.Type{NARSType}, type_name::String) = NARSType(type_name)
        # 注：占用枚举类名，也没问题（调用时返回「ERROR: LoadError: UndefVarError: `NARSType` not defined」）
        "名称→NARS类型（直接用宏调用）"
        macro NARSType_str(type_name::String)
            :($(NARSType(type_name))) # 与其运行时报错，不如编译时就指出来
        end

        "特殊打印格式：与宏相同"
        repr(nars_type::NARSType) = "NARSType\"$(nameof(nars_type))\"" # 注意：不能直接插值，否则「StackOverflowError」
        @redefine_show_to_to_repr nars_type::NARSType
        
    end

end

begin "NARSSentenceTemplete"
    
    "表示「自我」的对象"
    TERM_SELF::String = "{$SUBJECT_SELF}"

    """NARSSentenceTemplete
    注册与相应类型所对应的模板
    - 对应PyNEI中的「TEMPLETE_语句」常量集
    - 使用「字符串函数」封装模板
        - 因：Julia对「格式化字符串」支持不良
            - 没法使用「%s」组成「模板字符串」
        - 使用方法：直接封装一个「字符串生成函数」
            - 输入：若无特殊说明，则为对应的一个参数
            - 输出：字符串
    """
    struct NARSSentenceTemplete

        "指示「某个对象有某个状态」"
        sense::Function # NARSPerception
        
        "指示「自我有一个可用的（基本）操作」（操作注册）"
        register::Function # NARSOperation
        
        "指示「自我正在执行某操作」（无意识操作 Babble）"
        babble::Function # NARSOperation

        "指示「自我需要达到某个目标」"
        put_goal::Function # NARSGoal，其中以第二参数的形式包含「is_negative」即「负向目标」

        # "goal的负向版本"
        # put_goal_negative::Function

        "指示「某目标被实现」（奖励）"
        praise::Function # NARSGoal

        "指示「某目标未实现」（惩罚）"
        punish::Function # NARSGoal
        
    end

end
    
# 「具体注册」交给下面的jl：抽象功能与具体注册分离
include("CIN_Register_Templete.jl")

begin "注册后的一些方法（依赖注册表）"

    "检验NARSType的有效性：是否已被注册"
    isvalid(nars_type::NARSType)::Bool = nars_type ∈ ALL_CIN_TYPES

    "Type→SentenceTemplete（依赖字典）"
    function Base.convert(::Core.Type{NARSSentenceTemplete}, type::NARSType)::NARSSentenceTemplete
        NAL_TEMPLETE_DICT[type]
    end

    "名称→Type→SentenceTemplete（依赖字典）"
    function Base.convert(::Core.Type{NARSSentenceTemplete}, type_name::String)::NARSSentenceTemplete
        NAL_TEMPLETE_DICT[NARSType(type_name)]
    end

    "名称→NAL语句模板（直接用宏调用）（依赖字典）"
    macro NARSSentenceTemplete_str(type_name::String)
        :($(Base.convert(NARSSentenceTemplete, type_name))) # 与其运行时报错，不如编译时就指出来
    end # TODO：自动化「用宏生成宏？」
end