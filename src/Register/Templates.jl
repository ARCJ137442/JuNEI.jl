"""
现有库所支持之CIN(Computer Implement of NARS)注册项之模板

- 构造CIN注册项的数据结构
- 给注册项提供模板
"""
module Templates

import ...Support.Utils: input, @redefine_show_to_to_repr

# 导出

export CINRegister, @CINRegister_str

begin "CINRegister"

    """CINRegister
    注册与相应类型所对应的模板、处理函数
    - 对应PyNEI中的「template_语句」常量集
    - 使用「字符串函数」封装模板
        - 因：Julia对「格式化字符串」支持不良
            - 没法使用「%s」组成「模板字符串」
        - 使用方法：直接封装一个「字符串生成函数」
            - 输入：若无特殊说明，则为对应的一个参数
            - 输出：字符串
    - 亦封装「从『操作字符串』中截取操作」的部分
    """
    struct CINRegister

        #= 程序特性 =#

        "对应PyNEI中的「TYPE_CIN_DICT」，存储Type以达到索引「目标类构造方法」的目的"
        program_type::Type

        "对应PyNEI中被各个类实现的「launch_program」函数"
        exec_cmds::Function # executable_path::String -> Tuple{Cmd,Vector{String}}（可执行文件路径→(执行用Cmd,cmd命令序列)）
        
        "对应PyNEI中被各个类实现的「catch_operation」函数（现需要直接从字符串中获得操作）"
        operation_catch::Function # line::String -> Operation（包含「空操作」）

        #= 语句模板 =#

        "指示「某个对象有某个状态」"
        sense::Function # Perception -> String
        
        "指示「自我有一个可用的（基本）操作」（操作注册）"
        register::Function # Operation -> String
        
        "指示「自我正在执行某操作」（无意识操作 Babble）"
        babble::Function # Operation -> String

        "指示「自我需要达到某个目标」"
        put_goal::Function # Goal -> String，其中以第二参数的形式包含「is_negative」即「负向目标」

        "指示「某目标被实现」（奖励）"
        praise::Function # Goal -> String

        "指示「某目标未实现」（惩罚）"
        punish::Function # Goal -> String

        "指示「循环n个周期」"
        cycle::Function # Integer -> String

    end

    "外部构造方法：可迭代对象⇒参数展开"
    CINRegister(args::Union{Tuple, Vector}) = CINRegister(args...)

    "名称→NAL语句模板（直接用宏调用）"
    macro CINRegister_str(type_name::String)
        :($(Base.convert(CINRegister, type_name))) # 与其运行时报错，不如编译时就指出来
    end # TODO：自动化「用宏生成宏？」

end

end
