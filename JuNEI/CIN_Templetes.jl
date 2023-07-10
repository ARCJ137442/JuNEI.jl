"""现有库所支持之CIN(Computer Implement of NARS)的注册项（结构）
构造CIN注册项的数据结构
"""

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

begin "CINRegister"
    
    "表示「自我」的对象"
    TERM_SELF::String = "{$SUBJECT_SELF}"

    """CINRegister
    注册与相应类型所对应的模板、处理函数
    - 对应PyNEI中的「TEMPLETE_语句」常量集
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

        "对应PyNEI中的「TYPE_CIN_DICT」，存储Type以达到索引「目标类构造函数」的目的"
        program_type::Type

        "对应PyNEI中被各个类实现的「launch_program」函数"
        exec_cmds::Function # executable_path::String -> Tuple{Cmd,Vector{String}}（可执行文件路径→(执行用Cmd,cmd命令序列)）
        
        "对应PyNEI中被各个类实现的「catch_operation」函数（现需要直接从字符串中获得操作）"
        operation_catch::Function # line::String -> NARSOperation（包含「空操作」）

        #= 语句模板 =#

        "指示「某个对象有某个状态」"
        sense::Function # NARSPerception -> String
        
        "指示「自我有一个可用的（基本）操作」（操作注册）"
        register::Function # NARSOperation -> String
        
        "指示「自我正在执行某操作」（无意识操作 Babble）"
        babble::Function # NARSOperation -> String

        "指示「自我需要达到某个目标」"
        put_goal::Function # NARSGoal -> String，其中以第二参数的形式包含「is_negative」即「负向目标」

        "指示「某目标被实现」（奖励）"
        praise::Function # NARSGoal -> String

        "指示「某目标未实现」（惩罚）"
        punish::Function # NARSGoal -> String

    end

end
