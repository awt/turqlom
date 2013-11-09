class Turqlom::Post
  attr_accessor :post

  def initialize(post)
    @post = post
  end

  def file_name
    time = Time.new
    file_name = "#{time.year}-#{time.month}-#{time.day}"
    if !subject.nil?
      file_name += "-#{subject.split[0..5].join('_')}"
    end
    file_name += ".md"
    file_name
  end

  def subject
    @post.subject
  end

  def body
    @post.message
  end

  def address
    @post.from
  end
end
