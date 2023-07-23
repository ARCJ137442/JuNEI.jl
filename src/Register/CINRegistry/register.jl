"""
现有库所支持之CIN(Computer Implement of NARS)的注册项

注册在目前接口中可用的CIN类型
- OpenNARS(Java)
- ONA(C/C++)
- Python(Python)
- Junars(Julia)【WIP】
- 【未来还可更多】

📌注意：简化🆚效率
- 若想简化里面的「Dict(」与其它逗号（用Vector的向量表达，即concat一类函数）
    - 尽可能把代码往CINRegistry.jl移
    - 用向量代替参数逗号
- 效率牺牲：依照上面的简化方式，时间从「未简化」到「简化」变「1.655→2.095」
    - 足足慢了0.4s
"""

"几个对应的「CIN实现」注册（兼注册CIN类型）"

Dict(
    NARSType"OpenNARS" => CINRegister(

        # 使用命令行控制
        CINCmdline,

        # 程序启动命令
        (executable_path::String) -> (
            `java -Xmx1024m -jar $executable_path`,
            String[
                "*volume=0",
            ]
        ),

        #= 操作捕捉
        例句：
            EXE: $0.10;0.00;0.08$ ^pick([{SELF}, {t002}])=null
            EXE: $0.12;0.00;0.55$ ^want([{SELF}, <{SELF} --> [succeed]>, TRUE])=[$0.9000;0.9000;0.9500$ <{SELF} --> [succeed]>! %1.00;0.90%]
                TODO: 正则截取成了「succeed]>! %1.00;0.90%」
        =#
        (line::String) -> begin
            if contains(line, "EXE: ")
                # 使用正则表达式r"表达式"与「match」字符串方法，并使用括号选定其中返回的第一项
                m = match(r"\^(\w+)\((.*)\)", line)
                # 使用isnothing避免「假冒语句」匹配出错
                if !isnothing(m) && length(m) > 1
                    
                    return Operation(
                        m[1], # 匹配名称
                        split(m[2][2:end-1], r" *\, *") .|> String |> Tuple{Vararg{String}}
                        # ↑匹配参数（先用括号定位，再去方括号，最后逗号分隔）
                    )
                end
            end
            EMPTY_Operation
        end,
        
        # 感知
        (np::Perception) -> "<{$(np.subject)} --> [$(np.property)]>. :|:",
        
        # 注册操作
        (op::Operation) -> "<(*,$TERM_SELF_STR) --> ^$(op.name))>. :|:",

        # 无意识操作
        (op::Operation) -> "<(*,$TERM_SELF_STR) --> ^$(op.name))>. :|:",
        
        # 目标
        (ng::Goal, is_negative::Bool) -> (
            is_negative ? # 括号里可以用换行分隔三元运算符「? :」
              "(--, <$TERM_SELF_STR --> [$(ng.name)]>)! :|:" # 一个「负向目标」，指导「实现其反面」
            : "<$TERM_SELF_STR --> [$(ng.name)]>! :|:"
        ),
        
        # 奖
        (ng::Goal) -> "<$TERM_SELF_STR --> [$(ng.name)]>. :|:",
        
        # 惩 【20230721 23:14:11】TODO：有待整合并通用化——与NAL结合/合并入「通用语句输入」？或者就干脆保留特殊
        (ng::Goal) -> "<$TERM_SELF_STR --> [$(ng.name)]>. :|: %0%", # 通用的语法是「"(--,<$TERM_SELF_STR --> [%s]>). :|:"」

        # 循环周期
        (n::Integer) -> "$n",

    ),

    NARSType"ONA" => CINRegister(

        # 使用命令行控制
        CINCmdline,

        # 程序启动命令
        (executable_path::String) -> (
            `$executable_path shell`,
            String[
                "*volume=0",
            ]
        ),

        #= 操作捕捉
        例句：
            EXE ^right executed with args
            ^deactivate executed with args
            
            # TODO：找到ONA中「带参操作」的例句
        =#
        (line::String) -> begin
            if contains(line, "executed")
                # 使用正则表达式r"表达式"与「match」字符串方法，并使用括号选定其中返回的第一项
                m = match(r"\^(\w+)", line) # 使用「\w」匹配任意数字、字母、下划线
                !isnothing(m) && return Operation(m[1])
            end
            EMPTY_Operation
        end,
        
        # 感知
        (np::Perception) -> "<{$(np.subject)} --> [$(np.property)]>. :|:",
        
        # 注册操作
        (op::Operation) -> "(*,$TERM_SELF_STR, ^$(op.name)). :|:",

        # 无意识操作
        (op::Operation) -> "", # ONA无需Babble
        
        # 目标
        (ng::Goal, is_negative::Bool) -> (
            is_negative ?
              "(--, <$TERM_SELF_STR --> [$(ng.name)]>)! :|:" # 一个「负向目标」，指导「实现其反面」
            : "<$TERM_SELF_STR --> [$(ng.name)]>! :|:"
        ),
        
        # 奖
        (ng::Goal) -> "<$TERM_SELF_STR --> [$(ng.name)]>. :|:",
        
        # 惩
        (ng::Goal) -> "<$TERM_SELF_STR --> [$(ng.name)]>. :|: {0}",

        # 循环周期
        (n::Integer) -> "$n",

    ),

    NARSType"Python" => CINRegister(

        # 使用命令行控制
        CINCmdline,

        # 程序启动命令
        (executable_path::String) -> (
            `$executable_path`,
            String[]
        ),

        #= 操作捕捉
        例句：
            EXE: ^left based on desirability: 0.9
            # TODO：找到NARS Python中「带参操作」的例句
        =#
        (line::String) -> begin
            if contains(line, "EXE: ")
                # 使用正则表达式r"表达式"与「match」字符串方法，并使用括号选定其中返回的第一项
                m = match(r"\^(\w+)", line)
                !isnothing(m) && return Operation(m[1])
            end
            EMPTY_Operation
        end,
        
        # 感知
        (np::Perception) -> "({$(np.subject)} --> [$(np.property)]). :|:",
        
        # 注册操作
        (op::Operation) -> "((*,$TERM_SELF_STR) --> $(op.name)). :|:",

        # 无意识操作
        (op::Operation) -> "((*,$TERM_SELF_STR) --> $(op.name))). :|:",
        
        # 目标
        (ng::Goal, is_negative::Bool) -> (
            is_negative ?
              "($TERM_SELF_STR --> (-, [$(ng.name)]))! :|:" # 一个「负向目标」，指导「实现其反面」
            : "($TERM_SELF_STR --> [$(ng.name)])! :|:"
        ),
        
        # 奖
        (ng::Goal) -> "($TERM_SELF_STR --> [$(ng.name)]). :|:",
        
        # 惩
        (ng::Goal) -> "($TERM_SELF_STR --> [$(ng.name)]). :|: %0.00;0.90%",

        # 循环周期
        (n::Integer) -> "", # NARS-Python不启用
    ),

    TYPE_JUNARS => CINRegister(

        # 使用特制Junars类控制
        CINJunars,

        # 程序启动命令（不使用）
        (executable_path::String) -> nothing,

        #= 操作捕捉(WIP)
        例句：

        =#
        (line::String) -> begin
            @info "Operations WIP in Junars: $line"
            EMPTY_Operation
        end,
        
        # 感知
        (np::Perception) -> "<{$(np.subject)} --> [$(np.property)]>.", # 暂时移除时态「 :|:」（OpenJunars暂不支持时序推理）
        
        # 注册操作
        (op::Operation) -> "<(*,$TERM_SELF_STR) --> ^$(op.name))>.",

        # 无意识操作
        (op::Operation) -> "<(*,$TERM_SELF_STR) --> ^$(op.name))>.",
        
        # 目标
        (ng::Goal, is_negative::Bool) -> (
            is_negative ? # 括号里可以用换行分隔三元运算符「? :」
              "(--, <$TERM_SELF_STR --> [$(ng.name)]>)!" # 一个「负向目标」，指导「实现其反面」
            : "<$TERM_SELF_STR --> [$(ng.name)]>!"
        ),
        
        # 奖
        (ng::Goal) -> "<$TERM_SELF_STR --> [$(ng.name)]>.",
        
        # 惩
        (ng::Goal) -> "<$TERM_SELF_STR --> [$(ng.name)]>. %0%", # 通用的语法是「"(--,<$TERM_SELF_STR --> [%s]>). :|:"」

        # 循环周期
        (n::Integer) -> ":c $n", # 特殊命令✅

    ),
)