require_relative "Writer.rb"

class Assembler
  def initialize(asm_file_path)
    @asm_file_path = asm_file_path
    @hack_file_path = asm_file_path.gsub(".asm", ".hack")
    @binary_code_writer = Writer.new(@asm_file_path, @hack_file_path)
  end

  def compile_asm
    @binary_code_writer.write
  end
end

if __FILE__ == $0
  asm = Assembler.new(ARGV[0])
  asm.compile_asm
end
