"""有关NARS智能体(NARSAgent)与CIN(Computer Implement of NARS)的通信

前身：
- Boyang Xu, *NARS-FighterPlane*
- ARCJ137442, *NARS-FighterPlane v2.i alpha*

类の概览
- NARSType: 注册已有的CIN类型
- NARSProgram：抽象一个CIN通信接口
"""

begin "几个CIN实现的接口"
    
    """Java版实现：OpenNARS
    TODO：细化接口
    """
    mutable struct NARSProgram_OpenNARS <: NARSCmdline
        
        "程序路径"
        jar_path::String
        
        out_hook::Union{Function,Nothing}
        inference_cycle_frequency::Integer
    
        cached_inputs::Vector{String}
        
        process
        
        read_out_thread
        write_in_thread
        
        "宽松的构造函数（但顺序定死，没法灵活）"
        function NARSProgram_OpenNARS(
            jar_path::String,
            out_hook::Union{Function, Nothing} = nothing,
            inference_cycle_frequency::Integer = 5, # 使用Unsigned还需要「特别转换」不然就是Int64……还不如不用
            )::NARSProgram_OpenNARS
            new(jar_path, out_hook, inference_cycle_frequency, String[] #=空数组=#)
        end
    end

    begin "方法区"
        
        "重载超类：附加方法"
        function launch!(on::NARSProgram_OpenNARS)
            @super NARSCmdline launch!(on)
            add_to_cmd!(on, "*volume=0")
        end
        
        "重载「启动CIN」：加入指令"
        function launch_CIN!(on::NARSProgram_OpenNARS)
            @super Tuple{NARSCmdline, String} launch_CIN!(on,
            "java -Xmx1024m -jar $(on.jar_path)"
            )
            # 注：后面所有参数的类型，也要一一标注，不然就会报不明所以的错「invoke: argument type error」
        end
        
        "实现：捕捉操作名"
        function catch_operation_name(::NARSProgram_OpenNARS, line)
            @WIP catch_operation_name(::NARSProgram_OpenNARS, line)
        end
        
    end

    """C实现：OpenNARS for Application
    TODO：细化接口
    """
    mutable struct NARSProgram_ONA <: NARSCmdline
        
        "程序路径"
        exe_path::String
        
        out_hook::Union{Function,Nothing}
        inference_cycle_frequency::Integer
        
        cached_inputs::Vector{String}
        
        process
        
        read_out_thread
        write_in_thread
        
        "宽松的构造函数（但顺序定死，没法灵活）"
        function NARSProgram_ONA(
            exe_path::String,
            out_hook::Union{Function, Nothing} = nothing,
            inference_cycle_frequency::Integer = 0, # ONA自主更新
            )::NARSProgram_ONA
            new(exe_path, out_hook, inference_cycle_frequency, String[] #=空数组=#)
        end
    end
        
    begin "方法区"

        "重载超类：附加方法"
        function launch!(ona::NARSProgram_ONA)
            @super NARSCmdline launch!(ona)
            add_to_cmd!(ona, "*volume=0")
        end
        
        "重载「启动CIN」：加入指令"
        function launch_CIN!(ona::NARSProgram_ONA)
            @super Tuple{NARSCmdline, String} launch_CIN!(ona,
                "$(ona.jar_path) shell"
            )
        end

    end
    
    """Python实现：NARS Python
    TODO：细化接口
    """
    mutable struct NARSProgram_Python <: NARSCmdline
        
        "程序路径"
        exe_path::String
        
        out_hook::Union{Function,Nothing}
        inference_cycle_frequency::Integer
        
        cached_inputs::Vector{String}
        
        process
        
        read_out_thread
        write_in_thread

        "宽松的构造函数（但顺序定死，没法灵活）"
        function NARSProgram_Python(
            exe_path::String,
            out_hook::Union{Function, Nothing} = nothing,
            inference_cycle_frequency::Integer = 1, 
            )
            new(exe_path, out_hook, inference_cycle_frequency, String[] #=空数组=#)
        end
    end

    begin "方法区"
        
        "重载超类：附加方法"
        function launch!(npp::NARSProgram_Python)
            @super NARSCmdline launch!(npp)
            add_to_cmd!(npp, "*volume=0")
        end
        
        "重载「启动CIN」：加入指令"
        function launch_CIN!(npp::NARSProgram_Python)
            @super Tuple{NARSCmdline, String} launch_CIN!(npp,
            "$(npp.exe_path)"
            )
        end
        
    end
    
end

begin "实现接口后的注册"
    
    # NARSType→Type{NARSProgram} # 具体「有哪些类型」交给「注册」
    include("CIN_Register_Implement.jl")    
    
    "Type{NARSProgram}→NARSType"
    STRUCT_TYPE_DICT::Dict{Core.Type, NARSType} = Dict{Core.Type, NARSType}(
        @reverse_dict_content TYPE_STRUCT_DICT
    )

    begin "对应的转换方法(Program↔Type)"

        "Program类→Type"
        function Base.convert(::Core.Type{NARSType}, program_type::Core.Type{T})::NARSType where {T <: NARSProgram}
            STRUCT_TYPE_DICT[program_type]
        end

        "Program→Type：复现PyNEI中NARSProgram的「type」属性"
        function Base.convert(::Core.Type{NARSType}, program::NARSProgram)::NARSType
            STRUCT_TYPE_DICT[typeof(program)] # 无需递归实现
        end

        "Type→Program类" # 尽可能用Julia原装方法
        function Base.convert(::Core.Type{Core.Type{T}}, nars_type::NARSType)::Core.Type where {T <: NARSProgram}
            TYPE_STRUCT_DICT[nars_type]
        end
        
        "Type→Program：复现PyNEI中的NARSProgram.fromType函数（重载外部构造方法）"
        function NARSProgram(nars_type::NARSType, args...; kwargs...)::NARSProgram
            # 获得构造方法
            type_program = TYPE_STRUCT_DICT[nars_type] # Base.convert(Core.Type, nars_type) # 「Core.Type{NARSProgram}」会过于精确而报错「Cannot `convert` an object of type Type{NARSProgram_OpenNARS} to an object of type Type{NARSProgram}」
            # 调用构造方法
            type_program(args...; kwargs...)
        end

    end

    begin "对应的转换方法（SentenceTemplete↔Program类）"

        "Program→Type→SentenceTemplete（复现Python中各种「获取模板」的功能）" # 尽可能用Julia原装方法
        function Base.convert(::Core.Type{NARSSentenceTemplete}, program::NARSProgram)::NARSSentenceTemplete
            NAL_TEMPLETE_DICT[convert(NARSType, program)]
        end

    end
end