require 'cgi'
require 'json'

class Turqlom::Post
  include Client
  include Logging
  attr_accessor :post

  def initialize(post)
    @post = post
  end

  def file_name
    time = Time.new
    comment_reg_ex = /Comment\s+@(BM-\w+)\/(\w+)/
    isComment = !subject.match(comment_reg_ex).nil?
    # Added rjust for lexicographical ordering
    file_name = "#{time.year}-#{time.month.to_s.rjust(2,"0")}-#{time.day.to_s.rjust(2,"0")}"

    # Add received time from bit message client
    if (isComment == false)
      #if !subject.nil?
        #file_name += "-#{subject.split[0..5].join('_')}"
        file_name += "-"+msgid.to_s 
     #end
        file_name += ".md"
    # Post is a comment - No need to use Jekyll filename convention of articles/title
    # Use date/time for ascending order display
    else 
      file_name += "-"+ time.hour.to_s.rjust(2,"0")+"-"+time.min.to_s.rjust(2,"0")
      #file_name += "-"+msgid.to_s
      file_name += ".yaml"
    end
    file_name
  end

  def subject
    CGI.escapeHTML @post.subject
  end

  def body
    CGI.escapeHTML @post.message
  end

  def address
    @post.from
  end
  
  # New attribute added to front matter as address for comments
  def msgid
    @post.msgid
  end

  # New attribute added to front matter to show comment date/time
  def received_at
    @post.received_at
  end

  def delete_from_bitmessage
    if !Turqlom::SETTINGS['disable-bm']
      if defined? @post.msgid
        logger.info "Trashing message with id #{@post.msgid}"
        bm_api_client.trash_message @post.msgid
      end
    end
  end

  def base_url
    "http://#{Turqlom::SETTINGS['host']}/#{address}"
  end

  def storage_path
    File.join(Turqlom::SETTINGS['posts_path'], address)
  end

  def storage_file_name
    "#{post.msgid}.json"
  end

  def save
    FileUtils.mkdir_p(storage_path)
    path = File.join(storage_path, storage_file_name)
    logger.info("Storing post at: #{path}")
    # Added received_at field
    post = { subject: @post.subject, message: @post.message, msgid: @post.msgid, from: @post.from, received_at: @post.received_at.to_s}
    File.open(path, 'w+') do |file|
      file.write(post.to_s.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'}))
    end

    refresh
  end

  def post_path
    File.join(storage_path, storage_file_name)
  end

  def refresh
      begin
        @post = OpenStruct.new(JSON.parse(post_path))
      rescue
        @post = OpenStruct.new(eval(File.read(post_path)))
      end
  end
end
