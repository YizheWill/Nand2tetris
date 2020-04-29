require_relative "Tokenizer.rb"

class CompileEngine

    Integer = /^\d+$/
    String = /^\"[^"]*\"$/
    Keyword = /^true|false|null|this$/
    Identifier = /^[a-zA-Z]+[a-zA-Z_0-9]*$/
    Unary = /^-|~$/
    Op = /^\+|\-|\*|\/|\&|\||<|>|=$/
    Sub = /^\(|\[|\.$/
    
    def initialize(xml_file_path)
        @xml_file = File.open(xml_file_path, "w")
    end

    def set_tokenizer(jack_file_path)
        @tknzr = Tokenizer.new(jack_file_path, @xml_file)
    end

    def write
        write_labels(start: true, statement: "class")
        fastforward(3)
        compile_classVarDec until @tknzr.command_seg != "classVarDec"
        compile_subroutineDec until @tknzr.command_seg != "subroutineDec"
        fastforward #print }
        @xml_file.write("</class>\n")
    end

    def compile_classVarDec(vardec: false)
        write_labels(statement: "#{vardec ? "varDec" : "classVarDec"}")
        fastforward until command == ";"
        fastforward
        write_labels(start: false, statement: "#{vardec ? "varDec" : "classVarDec"}")
    end

    def compile_subroutineDec
        write_labels(statement: "subroutineDec")
        fastforward(4) # print "function/method returnType funcName ("
        write_labels(statement: "parameterList")
        fastforward until command == ")"
        write_labels(start: false, statement: "parameterList")
        fastforward #print ")"
        write_labels(statement: "subroutineBody")
        fastforward #print "{"
        compile_classVarDec(vardec: true) until @tknzr.command_seg != "varDec"
        compile_statements
        fastforward #print }
        write_labels(start: false, statement: "subroutineBody")
        write_labels(start: false, statement: "subroutineDec")
    end

    def compile_statements
        if @tknzr.command_seg == "statements" # just in case that the subroutine doesn't have a statement
            write_labels(statement: "statements")
            compile_statement until @tknzr.command_seg != "statements"
            write_labels(start: false, statement: "statements")
        end
    end

    def compile_statement
        stmt = "#{command}Statement"
        write_labels(statement: stmt)
        case command
        when "while", "if"
            compile_while_if
        when "let"
            compile_let
        when "do"
            compile_do
        when "return"
            compile_return
        end
        write_labels(start: false, statement: stmt)
    end

    def compile_while_if
        fastforward(2) #print "while (" "if (" 
        compile_expression
        fastforward(2) #print ") {" ") {"
        compile_statements
        fastforward #print "}"
        if command == "else"
            fastforward(2) #print "else {"
            compile_statements
            fastforward #print "}"
        end
    end

    def compile_let
        while command != "="
            command == "[" ? compile_expression_list(sub_call: false) : fastforward
        end
        compile_expression_list(sub_call: false)
    end

    def compile_return
        fastforward #print "return"
        compile_expression if command != ";"
        fastforward #print ";"
    end

    def compile_do
        fastforward(2) #print "do" and the function name or array name imagine "obj_arr[3].callfunc"
        compile_subroutineCall
        fastforward #print ";"
    end

    def compile_subroutineCall(end_term: false)
        while command.match(Sub)
            case command
            when "("
                compile_expression_list
            when "."
                fastforward(2)
            when "["
                compile_expression_list(sub_call: false)
            end
        end
        write_labels(start: false, statement: "term") if end_term
    end
    
    def compile_expression_list(sub_call: true)
        fastforward #print "("
        write_labels(statement: "expressionList") if sub_call
        if sub_call
            (command == "," ? fastforward : compile_expression) until command == ")"
        else
            compile_expression
        end
        write_labels(start: false, statement: "expressionList") if sub_call
        fastforward #print ")" 
    end

    def compile_expression(expression: true)
        write_labels(statement: "expression") if expression
        write_labels(statement: "term")
        case current_expression_seg
        when "integerConstant", "stringConstant", "keywordConstant"
            fastforward
            compile_op 
        when "unaryOp"
            compile_op(write_statement: false, unary: true)
        when "identifier"
            fastforward
            command.match(Op) ? compile_op : compile_subroutineCall(end_term: true)
        when "("
            compile_expression_list(sub_call: false)
            compile_op
        else
            return nil
        end
        write_labels(start: false, statement: "expression") if expression
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
            # has some logic flaw here: if symbol is "-", the program will always
            # recognize it as a "Unary", but sometimes it can be an Op
            return "unaryOp"
        elsif command.match(Op)
            return "Op"
        elsif command == "("
            return "("
        end
    end
    
    def compile_op(write_statement: true, unary: false)
        write_labels(start: false, statement: "term") if write_statement
        if command.match(Op) || command.match(Unary)
            fastforward
            compile_expression(expression: false)
        end
        write_labels(start: false, statement: "term") if unary
    end

    # return the current command
    def command
        @tknzr.current_command
    end

    # write tags that will take several lines, start: true will print "<tag>", else "</tag>"
    def write_labels(start: true, statement:)
        @xml_file.write("<#{start ? "" : "/"}#{statement}>\n")
    end

    # fastforward is to print the simple "<tag> name </tag>" lines
    def fastforward(n=1)
        n.times do 
            @tknzr.write_command
            @tknzr.advance
        end
    end

    #close the file
    def close
        @xml_file.close
    end
end