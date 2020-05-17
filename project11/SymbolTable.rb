class SymbolTable
    attr_accessor :parent_node, :hash, :previous, 
                  :static, :field, :var, :argument
    CLASS = /^static|field$/
    SUBROUTINE = /^var|argument$/
    def initialize(parent_node: nil, scope: "class")#()
        @hash = {}
        @static = 0
        @field = 0
        @var = 0
        @argument = 0
        @parent_node = parent_node
        @scope = scope
        create_funcs
    end

    def define(name:, type:, kind:)
      @type = type
      @kind = kind
      @hash[name] = {type:type, kind:kind, index: var_count(kind: kind, inc: true),scope: check_scope}
    end

    def start_subroutine(method: false)
        clean_local_symbols
    end

    def var_count(kind:, inc: false)
        index = self.send(kind)
        self.send("#{kind}=", index + 1) if inc
        return index
    end

    def check_scope
        @scope
    end

    def create_funcs
        %w(kind type index).each do |funcname|
            define_singleton_method("#{funcname}_of") do |symbol_name|
                return nil if !search_symbol(symbol_name)
                res = search_symbol(symbol_name)[funcname.to_sym]
                return "this" if res == "field"
                return "local" if res == "var"
                return res
            end
        end
    end

    def clean_symbols(copy_field=false)
        @hash = {}
        @type = nil
        @kind = nil
        @scope = nil
        @static = 0
        @field = 0
        @var = 0
        @argument = 0
        @previous = nil
        
        if copy_field
            newp = SymbolTable.new
            @parent_node.hash.each_key do |k|
                if @parent_node.hash[k][:kind] == "static"
                    newp.define(name: k, type: @parent_node.hash[k][:type], kind: "static")
                end
            end
            @parent_node = newp
        end
    end

    def dup(name)
      define(name: name, type: @type, kind: @kind)
    end

    def search_symbol(symbol_name)
        tmp_parent = @parent_node
        tmp_hash = @hash
        while !@hash.has_key?(symbol_name) && @parent_node
            @hash = parent_node.hash
            @parent_node = @parent_node.parent_node
        end
        res = @hash.has_key?(symbol_name) ?  @hash[symbol_name] : nil
        @hash = tmp_hash
        @parent_node = tmp_parent
        return res
    end

    def simplified_search_symbol(symbol_name)
        return @hash[symbol_name] if @hash.has_key?(symbol_name)
        return nil if !@parent_node
        return @parent_node.hash[symbol_name]
    end
end