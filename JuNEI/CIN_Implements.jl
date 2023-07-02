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

    "重载超类：附加方法"
    function launch!(on::NARSProgram_OpenNARS)
        @super NARSCmdline launch!(on)
        add_to_cmd!(on, "*volume=0")
    end
    
    "实现「启动CIN」"
    function launch_CIN!(on::NARSProgram_OpenNARS)
        @WIP launch_CIN!(on::NARSProgram_OpenNARS)
    end
    
    "实现：捕捉操作名"
    function catch_operation_name(::NARSProgram_OpenNARS, line)
        @WIP catch_operation_name(::NARSProgram_OpenNARS, line)
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
        
    "重载超类：附加方法"
    function launch!(ona::NARSProgram_ONA)
        @super NARSCmdline launch!(ona)
        add_to_cmd!(ona, "*volume=0")
    end
    
    
    """Python实现：NARS Python
    TODO：细化接口
    """
    mutable struct NARSProgram_Python <: NARSCmdline
        
        "程序路径"
        exe_path::String
        
        out_hook::Union{Function,Nothing}
        
        cached_inputs::Vector{String}
        inference_cycle_frequency::Integer
        
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
end