class Tokenizer
    KEYWORDS = /^(class|constructor|method|function|field|static|var|int|char|boolean|void|true|false|null|this|let|do|if|else|while|return)$/
    SYMBOLS = /^({|}|\(|\)|\[|\]|\.|\,|\;|\+|\-|\*|\/|\&|\||<|>|=|-|~)$/
    INTS = /^\d+$/
    STRINGS = /^"[^"\n\r]*"$/
    IDENTIFIER = /^[a-zA-Z]+[a-zA-Z_0-9]*$/
    attr_reader :current_command, :commands
    def initialize(file_path)
        @input_file = File.open(file_path, "r")
        @current_index = 0
        @current_command = ""
        @commands = []
    end

    def has_more_lines?
        !@input_file.eof?
    end

    def line_no
        return @input_file.lineno
    end

    def delete_comments
        while @current_line.include?("/**")
            while !end_of_file? && !@current_line.include?("*/")
                @current_line = @input_file.gets.strip
            end
            return nil if !has_more_lines?
            @current_line.gsub!(/\/\*\*.*\*\//, "")
            @current_line.gsub!(/.*\*\//, "")
        end
    end

    def line_advance
        while has_more_lines? 
            @current_line = @input_file.gets.strip.gsub(/(\/\/.*)|\r|\n/, "")
            delete_comments
            return @current_line if !@current_line || !@current_line.empty?
        end
    end

    def end_of_file?
        !has_more_lines? && (@commands && @current_index == @commands.count)
    end

    def advance
        if @current_index == @commands.count
            return nil if !line_advance
            @current_index = 0
            split_line
        end
        @current_index += 1
        return @current_command = @commands[@current_index - 1]
    end

    def command_type
        if @current_command.match(KEYWORDS)
            return("keyword")
        elsif @current_command.match(SYMBOLS)
            return("symbol")
        elsif @current_command.match(INTS)
            return("integerConstant")
        elsif @current_command.match(STRINGS)
            return("stringConstant")
        else
            return("identifier")
        end
    end


    def command_seg
        case @current_command
        when "class"
            return "class"
        when "static", "field"
            return "classVarDec"
        when "constructor", "function", "method"
            return "subroutineDec"
        when "var"
            return "varDec"
        when "if", "while", "do", "return", "let"
            return "statements"
        else
            return "else"
        end
    end

    def write_token_file
        while !end_of_file?
            advance
            write_command
        end
        @xml_file.close
        close
    end

    def close
        @input_file.close
    end


    private
    
    def split_line
        @commands = split_symbols(@current_line) 
    end

    def split_symbols(string)
        i = 0
        res = []
        strings = string.split(/(")/)
        while i < strings.length
            if strings[i] == '"'
                if strings[i + 1] != '"'
                    res << '"' + strings[i + 1] + '"'
                    i += 1
                else
                    res << '""'
                end
                i += 1
            else
                res << strings[i].split(/ |({|}|\(|\)|\[|\]|\.|\,|\;|\+|\-|\*|\/|\&|\||<|>|=|-|~)/)
            end
            i += 1
        end
        return res.flatten.select {|s| !s.empty?}
    end
end