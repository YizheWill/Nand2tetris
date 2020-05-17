require_relative "CompileEngine.rb"
class JackAnalyzer
    def initialize(path)
        path = path[0...-1] if path[-1] == "/"
        @jack_path = File.expand_path(path)
        if path[-5..-1] == ".jack"
            @single_file = true
        else
            @single_file = false
        end
        p @single_file
    end

    def compile
        @single_file ? compile_one(@jack_path) : compile_all
        @compileengine.close
    end

    private
    def compile_one(jack_path)
        xml_path = jack_path.gsub(".jack", ".xml")
        @compileengine = CompileEngine.new(xml_path)
        p "Engine Created"
        @compileengine.set_tokenizer(jack_path)
        p "Tokenizer Created"
        @compileengine.write
        @compileengine.close
    end

    def compile_all
        p "compiling a folder"
        Dir["#{@jack_path}/*.jack"].each do |file| 
            p file
            compile_one(file)
        end

    end
end

if __FILE__ == $0
    JackAnalyzer.new(ARGV[0]).compile
end