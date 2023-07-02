"""现有库所支持之CIN(Computer Implement of NARS)的注册项
注册在目前接口中可用的CIN类型
- OpenNARS(Java)
- ONA(C/C++)
- Python(Python)
- 【未来还可更多】
"""

include("Elements.jl")

begin "NARSType"
    
    """NARSType：已有CIN类型的枚举类
    """
    @enum NARSType begin
        NARSType_OpenNARS = 1 # Julia枚举的值不能是字符串……
        NARSType_ONA = 2
        NARSType_Python = 3
    end
    
    "构建一个字典，存储从NARSType到字符串名字的映射"
    TYPE_NAME_DICT::Dict{NARSType, String} = Dict{NARSType, String}(
        NARSType_OpenNARS => "OpenNARS",
        NARSType_ONA => "ONA",
        NARSType_Python => "Python",
        )
        
        "构造反向字典"
    NAME_TYPE_DICT::Dict{String, NARSType} = Dict{String, NARSType}(
        v => k
        for (k,v) in TYPE_NAME_DICT
    )
    
    begin "方法区" # 实际上这相当于「第一行使用字符串」的表达式，但「无用到可以当注释」
        
        "NARS类型→名称"
        nameof(nars_type::NARSType)::String = TYPE_NAME_DICT[nars_type]
        string(nars_type::NARSType)::String = nameof(nars_type)
        Base.convert(::Core.Type{String}, nars_type::NARSType) = nameof(nars_type)
        
        "名称→NARS类型（直接用宏调用）"
        macro NARSType_str(type_name::String)
            :($(NAME_TYPE_DICT[type_name])) # 与其运行时报错，不如编译时就指出来
        end
        
        "名称→NARS类型（直接用宏调用）"
        Base.convert(::Core.Type{NARSType}, type_name::String) = NAME_TYPE_DICT[type_name]
        # 注：占用枚举类名，也没问题（调用时返回「ERROR: LoadError: UndefVarError: `NARSType` not defined」）
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
    """
    struct NARSSentenceTemplete

        "指示「某个对象有某个状态」"
        sense::Function
        
        "指示「自我有一个可用的（基本）操作」（操作注册）"
        register::Function
        
        "指示「自我正在执行某操作」（无意识操作 Babble）"
        babble::Function

        "指示「自我需要达到某个目标」"
        goal::Function

        "goal的负向版本"
        goal_negative::Function

        "指示「某目标被实现」"
        praise::Function

        "指示「某目标未实现」"
        punish::Function
        
    end

    NAL_TEMPLETE_DICT::Dict = Dict(
        NARSType"OpenNARS" => NARSSentenceTemplete(
            
            # 感知
            (np::NARSPerception) -> "<{$(np.subject)} --> [$(np.adjective)]>. :|:",
            
            # 注册操作
            (op::NARSOperation) -> "<(*,$TERM_SELF) --> ^$(op.name))>. :|:",

            # 无意识操作
            (op::NARSOperation) -> "<(*,$TERM_SELF) --> ^$(op.name))>. :|:", # 注意：是操作的名字
            
            # 目标
            (ng::NARSGoal) -> "<$TERM_SELF --> [$(ng.name)]>! :|:",
            (ng::NARSGoal) -> "(--, <$TERM_SELF --> [$(ng.name)]>)! :|:", # 一个「负向目标」，指导「实现其反面」
            
            # 奖
            (ng::NARSGoal) -> "<$TERM_SELF --> [$(ng.name)]>. :|:",
            
            # 惩
            (ng::NARSGoal) -> "<$TERM_SELF --> [$(ng.name)]>. :|: %0%", # 通用的语法是「"(--,<$TERM_SELF --> [%s]>). :|:"」
        ),

        NARSType"ONA" => NARSSentenceTemplete(
            
            # 感知
            (np::NARSPerception) -> "<{$(np.subject)} --> [$(np.adjective)]>. :|:",
            
            # 注册操作
            (op::NARSOperation) -> "(*,$TERM_SELF, ^$(op.name)). :|:",

            # 无意识操作
            (op::NARSOperation) -> "<(*,$TERM_SELF) --> ^$(op.name))>. :|:", # 注意：是操作的名字
            
            # 目标
            (ng::NARSGoal) -> "<$TERM_SELF --> [$(ng.name)]>! :|:",
            (ng::NARSGoal) -> "(--, <$TERM_SELF --> [$(ng.name)]>)! :|:", # 一个「负向目标」，指导「实现其反面」
            
            # 奖
            (ng::NARSGoal) -> "<$TERM_SELF --> [$(ng.name)]>. :|:",
            
            # 惩
            (ng::NARSGoal) -> "<$TERM_SELF --> [$(ng.name)]>. :|: {0}",
        ),

        NARSType"Python" => NARSSentenceTemplete(
            
            # 感知
            (np::NARSPerception) -> "({$(np.subject)} --> [$(np.adjective)]). :|:",
            
            # 注册操作
            (op::NARSOperation) -> "((*,$TERM_SELF) --> $(op.name)). :|:",

            # 无意识操作
            (op::NARSOperation) -> "((*,$TERM_SELF) --> $(op.name))). :|:", # 注意：是操作的名字
            
            # 目标
            (ng::NARSGoal) -> "($TERM_SELF --> [$(ng.name)]>! :|:",
            (ng::NARSGoal) -> "($TERM_SELF --> (-, [$(ng.name)]))! :|:", # 一个「负向目标」，指导「实现其反面」
            
            # 奖
            (ng::NARSGoal) -> "($TERM_SELF --> [$(ng.name)]). :|:",
            
            # 惩
            (ng::NARSGoal) -> "($TERM_SELF --> [$(ng.name)]). :|: %0.00;0.90%",
        ),
    )
end