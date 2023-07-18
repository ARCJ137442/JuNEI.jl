push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）

import JuNEI
using JuNEI.CIN

ENV["JULIA_DEBUG"] = JuNEI

"================Test for Junars================" |> println

hook_f(content) = println("Hook! Junars says: $content")

FOLDER::String = "OpenJunars-main"

cj = CINJunars(
    "../../../$FOLDER", # 这里使用了相对路径，仅在此计算机中有效（其它环境需自行更改）
    hook_f
)

launch!(cj, "../../../../$FOLDER", "../../$FOLDER")
# @show cj # 启动后一打印一大片。。。

# 使用while+sleep等待Junars加载完毕
while !isAlive(cj)
    sleep(1)
end

cjput(inp) = put!(cj, inp)

[
    "<{SELF} --> [good]>."
    "<{SELF} --> [left]>."
] |> cjput
cycle!(cj, 5)

[
    "<A --> B>."
    "<A --> C>."
    "<B --> C>?"
] |> cjput
@show cj.oracle.taskbuffer
@assert isAlive(cj)

ENV["JULIA_DEBUG"] = Main # 启用DEBUG模式

cycle!(cj, 20)

#= 目前三段论推理可能会出现错误
    ERROR: LoadError: UndefVarError: `conversion` not defined
    Stacktrace:
    [1] matchreverse(j1::Junars.Gene.Inheritance, j2::Junars.Gene.Inheritance, nar::Junars.Admins.Nar)
    @ Junars.Inference [...]/OpenJunars/src/inference/syllogism.jl:204
    [2] syllogisim_aa(j1::Junars.Gene.Inheritance, j2::Junars.Gene.Inheritance, figure::Int64, nar::Junars.Admins.Nar)
    @ Junars.Inference [...]/OpenJunars/src/inference/syllogism.jl:94
    [3] syllogisim(j1::Junars.Gene.Inheritance, j2::Junars.Gene.Inheritance, nar::Junars.Admins.Nar)
    @ Junars.Inference [...]/OpenJunars/src/inference/syllogism.jl:30
=#

showtracks(cj)

sleep(3)

@info "终止Junars。。。"

terminate!(cj)

#=
JUNARS_PATHS = raw"[...]/OpenJunars"
PACKAGE_NAMES = "Junars", "DataStructures"

"导入路径&导入Julia包"
function import_external_julia_package(package_paths::Union{AbstractArray, Tuple}, module_names::Union{AbstractArray, Tuple})
    # 导入所有路径
    push!(LOAD_PATH, package_paths...)

    # 导入所有包
    for package_name in module_names
        @eval using $(Symbol(package_name))
    end
end

function import_external_julia_package(package_path::AbstractString, module_names::Union{AbstractArray, Tuple})
    import_external_julia_package((package_path,), module_names)
end

function import_external_julia_package(package_path::AbstractString, package_name::AbstractString)
    import_external_julia_package((package_path,), (package_name,))
end

function launch!(package_paths, module_names)

    import_external_julia_package(package_paths, module_names)

    @info "Loaded Julia Packages `$module_names` at $package_paths"
    # using Junars

    # 直接继承自cmdline.jl

    task = @async @eval begin # 使用eval避免编译时报错
        
        """
        处理「冒号命令」
        参数「cmdStr」：不带冒号
        返回：命令是否被执行
        """
        function handleColonCmd(nacore::NaCore, cmdStr::String)

            mem = nacore.mem
            buffer = nacore.internal_exp

            args = split(cmdStr)

            if startswith("quit", args[1]) # 指令「quit」：退出
                return nothing
            elseif args[1] == "p" # 指令「:p」：打印跟踪
                @show count(mem)
                showtracks(mem)
                return true
            elseif startswith(args[1], "c") # 指令「:c」「:cp」：cycle 运行指定周期
                if cmdStr == "c" # 只有c：直接cycle
                    cycle!(nacore)
                    return true
                end
                # 若c/cp后面带参数：循环一定次数
                length(args) > 1 && for _ in 1:parse(Int, args[2])
                    cycle!(nacore)
                end
                # cp：打印跟踪
                if args[1] == "cp" # cp：先cycle，再打印跟踪
                    showtracks(mem)
                end
                return true
            end
            return false
        end

        function ignite(nacore::NaCore)
            while true
                # 输出彩色字符（绿色粗体→Junars→重置格式 ）
                # 参考链接：https://zhuanlan.zhihu.com/p/208768786
                print("/e[1;32m" * "Junars> " * "/e[0m")
                input = readline(stdin) |> strip |> string
                length(input) == 0 && continue
                # 冒号开头的特殊指令
                if startswith(input, ':')
                    # 从第二个开始，成功执行则不作为语句输入
                    response = handleColonCmd(nacore, input[2:end])
                    response && continue
                    isnothing(response) && return # quit指令
                end
                task = nothing
                try
                    addone(nacore, input) # 输入语句
                catch err
                    @error err # 展示err
                    continue
                end
            end
        end

        function addone(nacore, s::AbstractString)
            stamp = Stamp([nacore.serials[]], nacore.cycles[])
            task = parsese(s, stamp)
            put!(nacore.internal_exp, task)
            nacore.serials[] += 1
        end

        function showtracks(cpts::Narsche)
            for level in cpts.total_level:-1:1
                length(cpts.track[level]) == 0 && continue
                print("L$level: ")
                for racer in cpts.track[level]
                    print("{$(name(racer)); $(round(priority(racer), digits=2))}")
                end
                println()
            end
        end

        begin "Main"
            cycles = Ref{UInt}(0)
            serial = Ref{UInt}(0)

            oracle = NaCore(
                Narsche{Concept}(100, 10, 400), 
                Narsche{NaTask}(5, 3, 20), 
                MutableLinkedList{NaTask}(), serial, cycles # 这个需要 DataStructures 模块
            );

            ignite(oracle)

        end
    end
    @show task
end

task = launch!(JUNARS_PATHS, PACKAGE_NAMES)

task |> propertynames

sleep(5)

=#