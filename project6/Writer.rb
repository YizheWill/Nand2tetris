require_relative "Parser.rb"

class Writer
  A_INSTRUCTION = /^@\d+$/
  def initialize(asm_file_path, hack_file_path)
    @hack_file = File.open(hack_file_path, "w")
    @parser = Parser.new(asm_file_path)
  end

  def write
    while @parser.has_more_commands
      compile
    end
    @parser.close
    @hack_file.close
  end

  def compile
    if command.match(A_INSTRUCTION)
      compile_a_ins
    else
      compile_c_ins
      write_txt("", true)
    end
    @parser.advance
  end

  def compile_a_ins
    ains = command[1..-1].to_i.to_s(base=2)
    (16-ains.length).times {ains = "0" + ains}
    write_txt(ains, true)
  end

  def compile_c_ins
    write_txt("111")
    commands = command.split(/=|;/)
    if command.include?("=")
      compile_alu(commands[1].strip)
      compile_save_to(commands[0].strip)
      compile_jump_to("#{commands[2] ? commands[2].strip : nil}")
    else
      compile_alu(commands[0])
      compile_save_to("")
      compile_jump_to("#{commands[1] ? commands[1].strip : nil}")
    end
  end

  def compile_alu(cmd)
    cmd.include?("M") ? write_txt("1") : write_txt("0")
    case cmd
    when "0"
      write_txt("101010")
    when "1"
      write_txt("111111")
    when "-1"
      write_txt("111010")
    when "D"
      write_txt("001100")
    when "A", "M"
      write_txt("110000")
    when "!D"
      write_txt("001101")
    when "!A", "!M"
      write_txt("110001")
    when "-D"
      write_txt("001111")
    when "-A", "-M"
      write_txt("110011")
    when "D+1"
      write_txt("011111")
    when "A+1", "M+1"
      write_txt("110111")
    when "D-1"
      write_txt("001110")
    when "A-1", "M-1"
      write_txt("110010")
    when "D+A", "D+M"
      write_txt("000010")
    when "D-A", "D-M"
      write_txt("010011")
    when "A-D", "M-D"
      write_txt("000111")
    when "D&A", "D&M"
      write_txt("000000")
    when "D|A", "D|M"
      write_txt("010101")
    else
      p cmd
      raise "no such alu command"
    end
  end

  def compile_save_to(cmd)
    cmd.include?("A") ? write_txt("1") : write_txt("0")
    cmd.include?("D") ? write_txt("1") : write_txt("0")
    cmd.include?("M") ? write_txt("1") : write_txt("0")
  end

  def compile_jump_to(command)
    case command
    when nil, ""
      write_txt("000")
    when "JGT"
      write_txt("001")
    when "JEQ"
      write_txt("010")
    when "JGE"
      write_txt("011")
    when "JLT"
      write_txt("100")
    when "JNE"
      write_txt("101")
    when "JLE"
      write_txt("110")
    when "JMP"
      write_txt("111")
    end
  end

  private

  def command
    @parser.current_command
  end

  def write_txt(binaries, ending=false)
    @hack_file.write("#{binaries}#{ending ? "\n" : ""}")
  end
end
