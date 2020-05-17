class Parser
  A_INSTRUCTION = /^@\d+$/
  SYMBOL = /^@[a-zA-Z._\$\d]+$/
  def self.create_label_hash(hash)
    (0..15).each do |n|
      hash["@R#{n}"] = "@#{n.to_s}"
    end
    specials = %w(SP LCL ARG THIS THAT)
    p specials
    specials.each_with_index do |sym, ind|
      hash["@" + sym] = "@#{ind}"
      p hash["@" + sym]
    end
  end

  def initialize(asmfile_path)
    @file = File.open(asmfile_path, "r")
    @commands = []
    @labels = {}
    @counter = 0
    @index = 0
    @available_token = 16
    Parser.create_label_hash(@labels)
    readlines
    p @labels["@SP"]
  end

  def readlines
    while !@file.eof?
      @current_line = @file.gets.gsub(/\/\/.*/, "").strip
      if !@current_line.empty?
        if @current_line[0] == '('
          @labels["@" + @current_line[1..-2]] = "@#{@counter}"
        elsif @current_line.match(A_INSTRUCTION)
          @commands << @current_line
        elsif @current_line.match(SYMBOL) 
          @commands << set_tokens_mem_slot(@current_line)
          @counter += 1
        else
          @commands << @current_line
          @counter += 1
        end
      end
    end
  end

  def current_command
    @commands[@index]
  end

  def advance
    return false if @index == @commands.length
    @index += 1
    return @commands[@index]
  end

  def has_more_commands
    @index < @commands.length
  end

  def label_line_number(instruction)
    @labels[instruction]
  end

  def set_tokens_mem_slot(line)
    if !@labels.has_key?(line)
      @labels[line] = "@#{@available_token}"
      @available_token += 1
    end
    return @labels[line]
  end

  def close
    @file.close
  end

end
