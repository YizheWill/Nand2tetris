class Parser
    attr_reader :current_command
    def initialize(path_to_vm_file)
       @vm_file = File.open(path_to_vm_file, "r") 
    end

    def has_more_commands?
       !@vm_file.eof? 
    end

    def advance
        @current_command = @vm_file.gets.gsub(/\/\.+|\n|\r/, "")
    end

    def [](index)
        split_command[index]
    end

    def line_number
        @vm_file.lineno
    end

    def file_name
        File.basename(@vm_file.path, ".vm")
    end

private
    def split_command
        @current_command.split
    end
end

class CodeWriter
    def initialize(path_to_asm_file, single_file)
        @asm_file = File.open(path_to_asm_file, "w")
        @function_count = 1
        write_init if !single_file
    end

    def set_file_name(path_to_vm_file)
        @parser = Parser.new(path_to_vm_file)
    end

    def write
        while @parser.has_more_commands?
            if !@parser.advance.empty?
                translate
            end
        end
    end

    def translate
        case @parser[0]
        when "add","sub","eq","gt","lt","and","or","neg","not"
            write_arithmetic
        when "push"
            write_push
        when "pop"
            write_pop
        when "label"
            write_label
        when "goto","if-goto"
            write_goto
        when "call"
            write_call
        when "function"
            write_function
        when "return"
            write_return
        end
    end

    def write_arithmetic
        case @parser[0]
        when "add"
            arithmetic(calc: "+")
        when "sub"
            arithmetic(calc: "-")
        when "eq"
            arithmetic(calc: "-", jump_type: "JEQ")
        when "gt"
            arithmetic(calc: "-", jump_type: "JGT")
        when "lt"
            arithmetic(calc: "-", jump_type: "JLT")
        when "and"
            arithmetic(calc: "&")
        when "or"
            arithmetic(calc: "|")
        when "neg"
            arithmetic(calc: "-", unary: true)
        when "not"
            arithmetic(calc: "!", unary: true)
        end
    end

    def write_push
        case @parser[1]
        when "constant"
            push_stack(constant:@parser[2])
        when "static"
            load_static
            push_stack
        else
            load_memory
            push_stack
        end
    end

    def write_pop
        pop_stack
        if @parser[1] == "static"
            load_static(pop: true)
        else
            write_file(string: "@13\nM=D")
            load_memory(save_from_r13: true)
        end
    end

    def write_label
        write_file(string: "(#{@parser[1]})")
    end

    def write_goto
        if @parser[0] == "if-goto"
            pop_stack
            jump = true
        end
        write_file(string: "@#{@parser[1]}")
        write_file(string: "#{jump ? "D;JNE" : "0;JMP"}")
    end

    def write_function
        write_file(string: "(#{@parser[1]})")
        @parser[2].to_i.times do 
            write_file(string: "@0\nD=A")
            push_stack
        end
        @function_name = @parser[1]
    end

    def write_call(init: false)
        @argument_count = init ? 0 : @parser[2]
        function_init
        write_file(string: "@#{init ? "Sys.init" : @parser[1]}\n0;JMP")
        write_file(string: "(RETURN#{@function_count - 1})", comment: "return address of #{init ? "Sys.init" : @parser[1]}")
    end

    def write_return
        write_file(string: "@5\nD=A\n@LCL\nA=M-D\nD=M\n@15\nM=D")
        pop_stack
        write_file(string: "@ARG\nA=M\nM=D\nD=A+1\n@SP\nM=D")
        ["THAT", "THIS", "ARG", "LCL"].each do |register|
            write_file(string: "@LCL\nAM=M-1\nD=M\n@#{register}\nM=D")
        end
        write_file(string: "@15\nA=M", comment: "going back to the return address of #{@parser[1]}")
        write_file(string: "0;JMP")
    end

    def function_init
        write_file(string: "@RETURN#{@function_count}\nD=A")
        push_stack
        ["LCL", "ARG", "THIS", "THAT"].each do |register|
            write_file(string: "@#{register}\nD=M")
            push_stack
        end
        write_file(string: "@#{@argument_count.to_i + 5}\nD=A\n@SP\nD=M-D\n@ARG\nM=D\n@SP\nD=M\n@LCL\nM=D")
        @function_count += 1
    end

    def load_static(pop: false)
        write_file(string: "@#{@parser.file_name.upcase}.#{@parser[2]}")
        write_file(string: "#{pop ? "M=D" : "D=M"}")
    end

    def load_memory(pop: false, save_from_r13: false)
        symbol_hash = Hash["local", "LCL", "argument", "ARG", "this", "THIS", "that", "THAT",
        "pointer", "THIS", "temp", "5"]
        write_file(string: "@#{@parser[2]}")
        write_file(string: "D=A")
        write_file(string: "@#{symbol_hash[@parser[1]]}")
        write_file(string: "#{(@parser[1] == "temp" || @parser[1] == "pointer") ? "AD=A+D" : "AD=M+D"}")
        write_file(string: "#{save_from_r13 ? "@14\nM=D\n@13\nD=M\n@14\nA=M\nM=D" : "D=M"}")
    end


    def push_stack(constant: nil)
        write_file(string: "@#{constant}\nD=A") if constant
        write_file(string: "@SP\nA=M\nM=D\n@SP\nM=M+1")
    end

    def pop_stack(save_to_d: true)
        write_file(string: "@SP\nM=M-1\nA=M#{save_to_d ? "\nD=M" : ""}")
    end

    def jump(jump_type)
        write_file(string: "@TRUE_JUMP", set_file_name: true, label: "@")
        write_file(string: "D; #{jump_type}\nD=0")
        write_file(string: "@FALSE_NO_JUMP", set_file_name: true, label: "@")
        write_file(string: "0;JMP")
        write_file(string: "(TRUE_JUMP", set_file_name: true, label: "(")
        write_file(string: "D=-1")
        write_file(string: "(FALSE_NO_JUMP", set_file_name: true, label: "(")
    end

    def arithmetic(calc:, jump_type: nil, unary: false)
        pop_stack
        pop_stack(save_to_d: false) if !unary
        write_file(string: "D=#{unary ? "" : "M"}#{calc}D")
        jump(jump_type) if jump_type
        push_stack
    end

    def write_init
        write_file(string: "@256\nD=A\n@SP\nM=D")
        write_call(init: true)
    end

    def close
        @asm_file.close
    end

    private
    def write_file(string:"", set_line_number: false, comment: "", set_file_name: false, label: "")
        line_number = set_line_number ? @parser.line_number : ""
        if !set_file_name
            @asm_file.write("#{string}#{line_number}#{comment == "" ? "\n" : "//#{comment}\n"}")
        elsif label == "@"
            @asm_file.write("#{string}.#{@parser.file_name.upcase}.#{@parser.line_number}#{comment == "" ? "\n" : "//#{comment}\n"}")
        else
            @asm_file.write("#{string}.#{@parser.file_name.upcase}.#{@parser.line_number}#{comment == "" ? ")\n" : ")//#{comment}\n"}")
        end
    end
end

class VMTranslator
    def initialize(path)
        path = path[0...-1] if path[-1] == "/"
        @vm_path = File.expand_path(path)
        if path[-3..-1] == ".vm"
            file_name = path.split("/")[-1][0..-4]
            @asm_path = "#{@vm_path[0..-4]}.asm"
            @single_file = true
        else
            @asm_path = "#{@vm_path}/#{@vm_path.split("/")[-1]}.asm"
            @single_file = false
        end
        @writer = CodeWriter.new(@asm_path, @single_file)
    end

    def compile
        @single_file ? translate(@vm_path) : translate_all
        @writer.close
    end

    private
    def translate(vm_path)
        @writer.set_file_name(vm_path)
        @writer.write
    end

    def translate_all
        Dir["#{@vm_path}/*.vm"].each {|file| translate(file)}
    end
end

if __FILE__ == $0
    VMTranslator.new(ARGV[0]).compile
end