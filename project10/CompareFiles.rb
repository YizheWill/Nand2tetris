def comparefile(path1, path2)
    file1 = File.open(path1, "r")
    file2 = File.open(path2, "r")
    while (!file1.eof? && !file2.eof?)
        if file1.gets.strip != file2.gets.strip
            p "compare failed at #{file1.lineno}"
        end
    end
    file1.close
    file2.close
end

if __FILE__ == $0
    comparefile(ARGV[0], ARGV[1])
end