"""现有库所支持之CIN(Computer Implement of NARS)的注册项
注册在目前接口中可用的CIN类型
- OpenNARS(Java)
- ONA(C/C++)
- Python(Python)
- 【未来还可更多】
"""

"注册所有已经支持的CIN类型"
ALL_CIN_TYPES::Vector{NARSType} = String[
    "OpenNARS",
    "ONA",
    "Python",
] .|> NARSType # 箭头语法更方便

"几个对应的「NAL语句模板」注册"
NAL_TEMPLETE_DICT::Dict = Dict(
    NARSType"OpenNARS" => NARSSentenceTemplete(
        
        # 感知
        (np::NARSPerception) -> "<{$(np.subject)} --> [$(np.adjective)]>. :|:",
        
        # 注册操作
        (op::NARSOperation) -> "<(*,$TERM_SELF) --> ^$(op.name))>. :|:",

        # 无意识操作
        (op::NARSOperation) -> "<(*,$TERM_SELF) --> ^$(op.name))>. :|:",
        
        # 目标
        (ng::NARSGoal, is_negative::Bool) -> (
            is_negative ? # 括号里可以用换行分隔三元运算符「? :」
              "(--, <$TERM_SELF --> [$(ng.name)]>)! :|:" # 一个「负向目标」，指导「实现其反面」
            : "<$TERM_SELF --> [$(ng.name)]>! :|:"
        ),
        
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
        (op::NARSOperation) -> "", # ONA无需Babble
        
        # 目标
        (ng::NARSGoal, is_negative::Bool) -> (
            is_negative ?
              "(--, <$TERM_SELF --> [$(ng.name)]>)! :|:" # 一个「负向目标」，指导「实现其反面」
            : "<$TERM_SELF --> [$(ng.name)]>! :|:"
        ),
        
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
        (op::NARSOperation) -> "((*,$TERM_SELF) --> $(op.name))). :|:",
        
        # 目标
        (ng::NARSGoal, is_negative::Bool) -> (
            is_negative ?
              "($TERM_SELF --> (-, [$(ng.name)]))! :|:" # 一个「负向目标」，指导「实现其反面」
            : "($TERM_SELF --> [$(ng.name)]>! :|:"
        ),
        
        # 奖
        (ng::NARSGoal) -> "($TERM_SELF --> [$(ng.name)]). :|:",
        
        # 惩
        (ng::NARSGoal) -> "($TERM_SELF --> [$(ng.name)]). :|: %0.00;0.90%",
    ),
)