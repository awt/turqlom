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
    file_name = "#{time.year}-#{time.month}-#{time.day}"
    if !subject.nil?
      file_name += "-#{subject.split[0..5].join('_')}"
    end
    file_name += ".md"
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
    post = { subject: @post.subject, message: @post.message, msgid: @post.msgid, from: @post.from}
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
