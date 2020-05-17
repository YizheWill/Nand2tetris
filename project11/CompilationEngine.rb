require_relative "JackTokenizer.rb"
require_relative "SymbolTable.rb"
require_relative "VMWriter.rb"

class CompilationEngine

    Integer = /^\d+$/
    String = /^\"[^"]*\"$/
    Keyword = /^true|false|null|this$/
    Identifier = /^[a-zA-Z]+[a-zA-Z_0-9]*$/
    Unary = /^-|~$/
    Op = /^\+|\-|\*|\/|\&|\||<|>|=$/
    Sub = /^\(|\[|\.$/
    
    
    def initialize(vm_file_path)
        @hash = {}
        @vm_file = File.open(vm_file_path, "w")
        @class_table = SymbolTable.new
        @subroutine_table = SymbolTable.new(parent_node: @class_table, scope: "subroutine")
        @vm_writer = VMWriter.new(vm_file_path)
        create_ascii
    end

    def create_ascii
      i = 32
      ' !"#$%&'.each_char do |char|
        @hash[char] = i
        i += 1
      end
      @hash["'"] = i
      i += 1
      "()*+,-./".each_char do |char|
        @hash[char] = i
        i += 1
      end

      (0..9).each do |num|
        @hash[num.to_s] = i
        i += 1
      end

      ":;<=>?@".each_char do |char|
        @hash[char] = i
        i += 1
      end

      ("A".."Z").each do |char|
        @hash[char] = i
        i += 1
      end

      "[\\]^_`".each_char do |char|
        @hash[char] = i
        i += 1
      end

      ("a".."z").each do |char|
        @hash[char] = i
        i += 1
      end

      "{|}~".each_char do |char|
        @hash[char] = i
        i += 1
      end
    end

    def set_tokenizer(jack_file_path)
        @tknzr = Tokenizer.new(jack_file_path)
    end

    def write
        @class_name = fastforward(2)
        fastforward(2)
        compile_classVarDec until @tknzr.command_seg != "classVarDec"
        @class_var_count = @class_table.var_count(kind: "field")
        compile_subroutineDec until @tknzr.command_seg != "subroutineDec"
        fastforward #print }
    end

    def write_class_table(classtable = true)
        (command == "," ? @class_table.dup(fastforward) : @class_table.define(kind: command, type: fastforward, name: fastforward)) if classtable
        (command == "," ? @subroutine_table.dup(fastforward) : @subroutine_table.define(kind: command, type: fastforward, name: fastforward)) if !classtable
        fastforward
    end

    def compile_classVarDec(vardec: false, classtable: true)
        write_class_table(classtable) while command != ";"
        fastforward
    end

    def compile_parameterlist
      return if command == ")"
      if command == "," 
        fastforward
      else
        @subroutine_table.define(kind: "argument", type: command , name: fastforward)
        fastforward
      end
    end

    def compile_subroutineDec
      method = 0
        curr_function_type, curr_returntype, curr_funcname = command, fastforward, fastforward
        if curr_function_type == "function"
          @subroutine_table.clean_symbols(true)
        else
          @subroutine_table.clean_symbols
          @subroutine_table.parent_node = @class_table
        end
        method = 1 if curr_function_type == "method"
        fastforward(2)
        if method == 1
          @subroutine_table.define(name: "this", type: @class_name, kind: "argument")
        end
        compile_parameterlist while command != ")"
        fastforward #print ")"
        fastforward #print "{"
        compile_classVarDec(vardec: true, classtable: false) while @tknzr.command_seg == "varDec"
        @subroutine_var_count = @subroutine_table.var_count(kind: "var")
        @vm_writer.write_function(command_name: @class_name + "." + curr_funcname, varcount: @subroutine_var_count)
        compile_constructor if curr_function_type == "constructor"
        if method == 1
          write_vm("push argument 0")
          write_vm("pop pointer 0")
        end
        compile_statements
        fastforward #print }
    end

    def compile_constructor
        @vm_writer.write_push(segment: "constant", index: @class_var_count)
        @vm_writer.write_call(command_name: "Memory.alloc", argcount: 1)
        @vm_writer.write_pop(segment: "pointer", index: 0) 
    end

    def compile_statements
        if @tknzr.command_seg == "statements"
            compile_statement while @tknzr.command_seg == "statements"
        end
    end

    def compile_statement
        case command
        when "while"
            compile_while
        when "if"
            compile_if
        when "let"
            compile_let
        when "do"
            compile_do
        when "return"
            compile_return
        end
    end

    def compile_while
        start = @vm_writer.create_label(label: "WHILE", filename: @class_name, linenumber: @tknzr.line_no, start_or_end: "START")
        whileend = @vm_writer.create_label(label: "WHILE", filename: @class_name, linenumber: @tknzr.line_no, start_or_end: "END")
        @vm_writer.write_label(asmd_label: start)
        fastforward(2) 
        compile_expression
        write_vm("not")
        @vm_writer.write_if(asmd_label: whileend)
        fastforward(2) 
        compile_statements
        @vm_writer.write_goto(asmd_label: start)
        fastforward 
        @vm_writer.write_label(asmd_label: whileend)
    end

    def compile_if
        elsestart = @vm_writer.create_label(label: "ELSE", filename: @class_name, linenumber: @tknzr.line_no, start_or_end: "START")
        elseend = @vm_writer.create_label(label: "ELSE", filename: @class_name, linenumber: @tknzr.line_no, start_or_end: "END")
        fastforward(2) 
        compile_expression
        write_vm("not")
        @vm_writer.write_if(asmd_label: elsestart)
        fastforward(2) 
        compile_statements
        @vm_writer.write_goto(asmd_label: elseend)
        @vm_writer.write_label(asmd_label: elsestart)
        fastforward 
        if command == "else"
            fastforward(2) 
            compile_statements
            fastforward 
        end
        @vm_writer.write_label(asmd_label: elseend)
    end

    def compile_let
        fastforward 
        ccomand = command
        if fastforward == "["
          write_vm("push #{@subroutine_table.kind_of(ccomand)} #{@subroutine_table.index_of(ccomand)}") 
          fastforward
          compile_expression
          fastforward
          write_vm("add")
          fastforward 
          compile_expression 
          write_vm("pop temp 0\npop pointer 1\npush temp 0\npop that 0") 
        else
          fastforward
          compile_expression
          write_vm("pop #{@subroutine_table.kind_of(ccomand)} #{@subroutine_table.index_of(ccomand)}")
        end
        fastforward
    end

    def compile_return
        fastforward 
        if command == "this"
            @vm_writer.write_push(segment: "pointer", index: 0)
            fastforward
        elsif command != ";"
            compile_expression
        elsif command == ";"
            write_vm("push constant 0")
        end
        write_vm("return")
        fastforward 
    end

    def compile_do
        fastforward 
        compile_subroutineCall(call: true)
        @vm_writer.write_pop(segment: "temp", index: 0)
        fastforward 
    end

    def compile_subroutineCall(end_term: false, call: false, from_identifier: false)
      method = 0
      if from_identifier
        curr_varname = @previous_command
        curr_type_identifier = command
      else
        curr_varname = command
        curr_type_identifier = fastforward
      end
        if @subroutine_table.type_of(curr_varname) && @subroutine_table.type_of(curr_varname) != "Array"
            write_vm("push #{@subroutine_table.kind_of(curr_varname)} #{@subroutine_table.index_of(curr_varname)}")
            curr_funcname = "#{@subroutine_table.type_of(curr_varname)}" + "." + fastforward
            method = 1
            fastforward
        elsif @subroutine_table.type_of(curr_varname) == "Array"
          write_vm("push #{@subroutine_table.kind_of(curr_varname)} #{@subroutine_table.index_of(curr_varname)}")
          if command == "["
            fastforward
            compile_expression
            fastforward
            write_vm("add")
            write_vm("pop pointer 1")
            write_vm("push that 0")
            return
          end
          return
        elsif curr_type_identifier == "."
            curr_funcname = curr_varname + "." + fastforward
            fastforward
        elsif curr_type_identifier == "("
          method = 1
            write_vm("push pointer 0")
            curr_funcname = @class_name + "." + curr_varname
        else
          raise "no such subroutine"
        end
        c = compile_expression_list
        @vm_writer.write_call(command_name: curr_funcname, argcount: c + method)
    end
    
    def compile_expression_list(sub_call: true)
        fastforward if sub_call 
        if command == ")"
         fastforward
         return 0
        end
        i = 1
        
        if sub_call
          while command != ")"
            if command == ","
              fastforward
              i += 1
            else
              compile_expression
            end
          end
          fastforward 
          return i
        else
            compile_expression
            return i
        end
    end
    
    def compile_string
      str = command[1..-2]
      if str
        len = str.length
        write_vm("push constant #{len}")
        write_vm("call String.new 1")
        i = 0
        while (i < len)
          write_vm("push constant #{@hash[str[i]]}")
          write_vm("call String.appendChar 2")
          i += 1
        end
      else
        write_vm("push constant 0")
        write_vm("call String.new 1")
      end
    end

    def compile_expression(expression: true)
        case current_expression_seg
        when "integerConstant"
          write_vm("push constant #{command}")
            fastforward
            compile_op if command.match(Op)
        when "stringConstant"
          compile_string
            fastforward
        when "keywordConstant"
          case command
          when "false", "null" 
            write_vm("push constant 0")
          when "this"
            write_vm("push pointer 0")
          when "true"
            write_vm("push constant 0\nnot")
          end
            fastforward
        when "unaryOp"
            compile_op(write_statement: false, unary: true)
        when "identifier"
          curr = command
          @previous_command = curr
          nextc = fastforward
          if [".", "(", "["].include? nextc
              compile_subroutineCall(end_term: true, from_identifier: true)
          else
            if curr == "this"
              write_vm("push pointer 0")
            else
              write_vm("push #{@subroutine_table.kind_of(curr)} #{@subroutine_table.index_of(curr)}")
            end
          end
          compile_op if command.match(Op)
        when "("
          fastforward
            compile_expression
            fastforward
            compile_op if command.match(Op)
        else
            return nil
        end
    end

    def current_expression_seg
        if command.match(Integer)
            return "integerConstant"
        elsif command.match(String)
            return "stringConstant"
        elsif command.match(Keyword)
            return "keywordConstant"
        elsif command.match(Identifier)
            return "identifier"
        elsif command.match(Unary)
            return "unaryOp"
        elsif command.match(Op)
            return "Op"
        elsif command == "("
            return "("
        end
    end

    def write_unary(curr_command)
      case curr_command
      when "~"
        write_vm("not")
      when "-"
        write_vm("neg")
      else
        raise "no such operator"
      end
    end

    def write_op(curr_command)
      case curr_command
      when "+"
        write_vm("add")
      when "-"
        write_vm("sub")
      when "*"
        write_vm("call Math.multiply 2")
      when "/"
        write_vm("call Math.divide 2")
      when "<"
        write_vm("lt")
      when ">"
        write_vm("gt")
      when "="
        write_vm("eq")
      when "&"
        write_vm("and")
      when "|"
        write_vm("or")
      else
        raise "no such operation"
      end
    end
    
    def compile_op(write_statement: true, unary: false)
        current_command = command
        fastforward
        if current_command.match(Op) || current_command.match(Unary)
          compile_expression(expression: false)
          if unary
            write_unary(current_command)
          else
            write_op(current_command)
          end
        end
    end

    def command
        @tknzr.current_command
    end

    def fastforward(n=1)
        name = ""
        n.times do 
            name = @tknzr.advance
        end
        return name
    end

    def close
        @vm_file.close
    end

    def write_vm(commandline)
      @vm_writer.write_vm(command_line: commandline)
    end
  end
