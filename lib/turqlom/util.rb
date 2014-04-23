class Turqlom::Util
  class << self
    def write_template(in_path, out_path, &block)
      puts "out_path is " + out_path
      template = File.new(in_path).read
      erb = ERB.new template, nil, '%'
      File.open(out_path, 'w+') do |file|
        file.write(yield erb)
      end
    end
  end
end
