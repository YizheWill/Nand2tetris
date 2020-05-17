require_relative "CompilationEngine.rb"
class JackCompiler
    def initialize(path)
        path = path[0...-1] if path[-1] == "/"
        @jack_path = File.expand_path(path)
        if path[-5..-1] == ".jack"
            @single_file = true
        else
            @single_file = false
        end
    end

    def compile
        @single_file ? compile_one(@jack_path) : compile_all
        @jackcompiler.close
    end

    private
    def compile_one(jack_path)
        vm_path = jack_path.gsub(".jack", ".vm")
        @jackcompiler = CompilationEngine.new(vm_path)
        @jackcompiler.set_tokenizer(jack_path)
        @jackcompiler.write
        @jackcompiler.close
    end

    def compile_all
        Dir["#{@jack_path}/*.jack"].each do |file| 
            compile_one(file)
        end
        @jackcompiler.close

    end
end

if __FILE__ == $0
    JackCompiler.new(ARGV[0]).compile
end
