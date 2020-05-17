class VMWriter
    def initialize(vm_path)
        @vm_file = File.open(vm_path, "w")
    end

    def write_push(segment:, index:)
        write_vm(command_line: "push #{segment} #{index}")
    end

    def write_pop(segment:, index:)
        write_vm(command_line: "pop #{segment} #{index}")
    end

    def write_arithmetic(command:, unary: false)
        case command
        when "+"
            write_vm(command_line: "add")
        when "-"
            unary ? write_vm("sub") : write_vm("neg")
        when "="
            write_vm(command_line: "eq")
        when ">"
            write_vm(command_line: "gt")
        when "<"
            write_vm(command_line: "lt")
        when "&"
            write_vm(command_line: "and")
        when "|"
            write_vm(command_line: "or")
        when "~"
            write_vm(command_line: "not")
        else
            raise "not an arithmetic option"
        end
    end

    def create_label(label:, filename:, linenumber: nil, start_or_end: nil)
        return "#{label}#{start_or_end}.#{filename}.#{linenumber}"
    end

    def write_label(asmd_label:)
        write_vm(command_line: "label #{asmd_label}")
    end

    def write_goto(asmd_label:)
        write_vm(command_line: "goto #{asmd_label}")
    end

    def write_if(asmd_label:)
        write_vm(command_line: "if-goto #{asmd_label}")
    end

    def write_call(command_name:, argcount:)
        write_vm(command_line: "call #{command_name} #{argcount}")
    end

    def write_function(command_name:, varcount:)
        write_vm(command_line: "function #{command_name} #{varcount}")
    end

    def write_return(void: false)
        write_vm(command_line: "return")
        write_vm(command_line: "pop temp 0") if void
    end

    def close
        @vm_file.close
    end

    def write_vm(command_line:, continue: false)
        @vm_file.write(command_line+ "#{continue ? "" : "\n"}")
    end
end
