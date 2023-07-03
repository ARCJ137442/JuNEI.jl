"NARSType→Type{NARSProgram}"
TYPE_STRUCT_DICT::Dict{NARSType, Core.Type} = Dict{NARSType, Core.Type}(
    NARSType"OpenNARS" => NARSProgram_OpenNARS,
    NARSType"ONA" => NARSProgram_ONA,
    NARSType"Python" => NARSProgram_Python,
) # 注：使用「Core.Type{NARSProgram}」会因「过于精确」而报错
