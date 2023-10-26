"""
NAL元素(WIP)
- 定义一些「直接对应NAL元素」的类
- 部分定义、架构参考自OpenJunars

📝笔记：
- 「语句作为词项」本身是不准确的
    - 作为「语句成分」的`Statement`与作为「语句整体」
        - `Statement` <: `Term` 如: <A --> B>
        - `Sentence` ≈ `Statement` + Punct + Truth... 如: <A --> B>. %1.0; 0.9%
- 尽可能使用「抽象类结构」本身表示「词项继承关系」，而非依赖特殊的`type`属性

🔥现状：
- 【20230717 22:40:15】目前尚有许多概念分不清楚，若想构建好还需进一步分析Junars源码
"""
module NAL

using ..Utils # 使用上级模块（Support）的Utils

# ！统一在文件开头导出，而非在各个begin-end中export
export AbstractTerm, Term
export @Term_str

export AbstractAtom, AtomBasic, AtomInstance, AtomProperty
export SUBJECT_SELF_STR, TERM_SELF, TERM_SELF_STR

export AbstractCompound

export AbstractPunct, Statement, Goal, Question
export Sentence

    
"所有NAL词项的基类"
abstract type AbstractTerm end
    const Term = AbstractTerm # 别名（只在外面的类使用）

begin "原子词项"
    
    """
    所有「原子词项」的抽象基类
    - 理论来源：《Non-Axiomatic-Language》，《NAL》

    > 「The basic form of a term is a word, 
    > a string of letters in a finite alphabet.」
    > ——《NAL》
    """
    abstract type AbstractAtom <: AbstractTerm end

    """
    具体实现：原子词项 基础
    """
    struct AtomBasic <: AbstractAtom
        name::String
    end

    """
    具体实现：原子词项 {实例}
    【20230717 22:52:29】TODO：这里所谓「实例」实则为「外延集」
    """
    struct AtomInstance <: AbstractAtom
        name::String
    end

    """
    具体实现：原子词项 [属性]
    【20230717 22:52:29】TODO：这里所谓「属性」实则为「内涵集」
    """
    struct AtomProperty <: AbstractAtom
        name::String
    end

    begin "方法@原子词项"

        """
        从「词项类型」到「环绕字符串」
        【20230717 22:56:31】暂不使用「方法派发」的方式实现：无法再后续「自动转换」中检索
        """
        const TERM_TYPE_SURROUNDING_DICT::Dict{Type{<:AbstractAtom},String} = Dict(
            AtomInstance => "{}",
            AtomProperty => "[]",
        )
        
        begin "抽象类构造方法重用：自动词项转换"

            """
            （语法糖）复用抽象类构造方法（自动转换类型）
            - 映射关系：String -> Term
            """
            function AbstractTerm(raw::String)::AbstractTerm
                # (WIP)暂且返回「原子词项」
                AbstractAtom(raw)
            end
            
            """
            纯字符串⇒原子词项（自动转换类型）
            - 📌抽象类构造方法重用：相当于「自动转换词项」
            - 例：AbstractTerm("{SELF}") = AtomInstance("SELF")
            - 目前还只支持「原子词项」
            """
            function AbstractAtom(raw::String)::AbstractTerm
                t::Tuple{Function,Function} = (first, last) # 获取头尾的函数
                # 遍历判断
                for (type, surrounding) in TERM_TYPE_SURROUNDING_DICT
                    if !isempty(surrounding) && (surrounding .|> t) == (raw .|> t) # 头尾相等
                        return type(raw[2:end-1]) # 直接用类初始化
                    end
                end
                return AtomBasic(raw) # 默认为基础词项类型
            end
            
        end

        begin "字符串/显示 重载"

            "获取词项名"
            Base.nameof(::AbstractTerm)::String = @abstractMethod
            Base.nameof(aTerm::AbstractAtom)::String = aTerm.name
            
            "获取词项字符串&插值入字符串"
            function Base.string(aTerm::AbstractAtom)::String
                surrounding::String = TERM_TYPE_SURROUNDING_DICT[aTerm.type]
                if !isempty(surrounding)
                    return surrounding[1] * nameof(aTerm) * surrounding[end] # 使用字符串拼接
                end
                nameof(aTerm)
            end

            "快捷方式"
            Base.string(ab::AtomBasic) = nameof(ab)
            Base.string(ai::AtomInstance) = "{$(nameof(ai))}"
            Base.string(ap::AtomProperty) = "[$(nameof(ap))]"
            
            "格式化对象输出"
            Base.repr(aTerm::AbstractTerm)::String = "<NARS Term $(string(aTerm))>"
            
            # "控制在show中的显示形式"
            @redefine_show_to_to_repr aTerm::AbstractTerm
            
            macro Term_str(content::String)
                :(AbstractTerm($content))
            end

        end
    end

    begin "常量@原子词项"

        "内置常量：NARS内置对象名「自我」"
        const SUBJECT_SELF_STR::String = "SELF"
        
        "表示「自我」的词项"
        const TERM_SELF::AbstractTerm = AtomInstance(SUBJECT_SELF_STR)
    
        "表示「自我」的对象"
        const TERM_SELF_STR::String = string(TERM_SELF)

    end
end
    
begin "复合词项（WIP）"

    """
    复合词项の基类
    """
    abstract type AbstractCompound <: AbstractTerm end
    
    begin "语句词项 Statement（WIP）"
        
        export AbstractStatement
        
        abstract type AbstractStatement <: AbstractCompound end
        # TODO
    end
end

# "语句 Sentence（WIP）"
include("NAL/sentence.jl")

end
