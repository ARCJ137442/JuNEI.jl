"""
定义一些「直接对应NAL元素」的类
"""

begin "词项"
    
    begin "TermType"

        """定义对NARS（原子）词项类型的枚举
        理论来源：《Non-Axiomic-Language》，《NAL》
        """
        @enum TermType begin
            TermType_BASIC # 基础
            TermType_INSTANCE # {实例}
            TermType_PROPERTY # [属性]
            TermType_COMPOUND # 复合词项（语句词项是一个特殊的复合词项，故此处暂不列出）
        end
        
        "缩写字典：使用TermType'B'取类型"
        const TERM_TYPE_NAME_ABBREVIATION_DICT::Dict{String, TermType} = Dict(
            "B" => TermType_BASIC,
            "I" => TermType_INSTANCE,
            "P" => TermType_PROPERTY,
            "C" => TermType_COMPOUND,
        )
    
        "用宏定义缩写"
        macro TermType_str(name::String)
            :($(TERM_TYPE_NAME_ABBREVIATION_DICT[name]))
        end
    end
    
    "所有NAL词项的基类"
    abstract type Term end
    
    """原子词项：Atomic Term
    「The basic form of a term is a word, a string of letters in a
    finite alphabet.」——《NAL》"""
    struct AtomicTerm <: Term
        name::String
        type::TermType
    
        # AtomicTerm(name::String, type::TermType=TermType_BASIC) = new(
        #     name,
        #     type,
        # )
    end
    
    const TARM_TYPE_SURROUNDING_DICT::Dict{TermType,String} = Dict(
        TermType_BASIC => "",
        TermType_INSTANCE => "{}",
        TermType_PROPERTY => "[]",
        TermType_COMPOUND => "",
    )
    
    """纯字符串⇒原子词项（自动转换类型）
    例：AtomicTerm("{SELF}") = 例：AtomicTerm("SELF", TermType_INSTANCE)
    """
    function AtomicTerm(raw::String)
        t::Tuple{Function,Function} = (first, last)
        # 遍历判断
        for (type,surrounding) in TARM_TYPE_SURROUNDING_DICT
            if !isempty(surrounding) && (surrounding .|> t) == (raw .|> t) # 头尾相等
                return AtomicTerm(raw[2:end-1], type)
            end
        end
        return AtomicTerm(raw, TermType_BASIC) # 默认为基础词项类型
    end
    
    "获取词项名"
    Base.nameof(term::Term)::String = @abstractMethod
    Base.nameof(aterm::AtomicTerm)::String = aterm.name
    
    "获取词项字符串&插值入字符串" # 注意重载Base.string
    function Base.string(aterm::AtomicTerm)::String
        surrounding::String = TARM_TYPE_SURROUNDING_DICT[aterm.type]
        if !isempty(surrounding)
            return surrounding[1] * nameof(aterm) * surrounding[end] # 使用字符串拼接
        end
        nameof(aterm)
    end
    
    "格式化对象输出"
    Base.repr(term::Term)::String = "<NARS Term $(string(term))>"
    
    # "控制在show中的显示形式"
    @redefine_show_to_to_repr term::Term
    
    macro Term_str(content::String)
        :(Term($content))
    end
    
    "String -> Term"
    function Term(raw::String)::Term
        # 暂且返回「原子词项」
        return AtomicTerm(raw)
    end
end