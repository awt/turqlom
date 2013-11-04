class Turqlom::Post
  attr_accessor :post

  def initialize(post)
    @post = post
  end

  def file_name
    time = Time.new
    file_name = "#{time.year}-#{time.month}-#{time.day}"
    if !@post['subject'].nil?
      file_name += "-#{@post['subject'].split[0..5].join('_')}"
    end
    file_name += ".md"
    file_name
  end

  def blog_path
    File.join(Turqlom::SETTINGS.datapath, @post['address'])
  end

  def subject
    @post['subject']
  end

  def body
    @post['body']
  end

  def address
    @post['address']
  end
end
