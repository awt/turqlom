require 'ostruct'
require 'logger'
require 'bitmessage'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'erb'

class Turqlom::Blog
  include Logging

  attr_accessor :address

  def initialize(address)
    @address = address
    initialize_path
  end

  def path
    File.join(Turqlom::SETTINGS.staging_path, @address)
  end

  def blog_template
    Turqlom::SETTINGS.blog_template
  end

  def initialize_path
    #create address folder if it doesn't exist
    if !File.directory? path
      logger.info "Creating blog directory: #{path}"
      FileUtils.mkdir_p(path)

      #clone custom balzac repo into blog_dir
      `git clone #{blog_template} #{path}`
    end
  end

  def update_path
    if File.directory? path
      Dir.chdir(path) do
        logger.info("#{path} already exists.  Updating from git..")
        `git pull`
      end
    end
  end

  def url
    url = "http://#{Turqlom::SETTINGS['host']}/#{@address}"
  end

  #update jekyll config with url
  def write_jekyll_config
    logger.info("Writing jekyll config.")
    Turqlom::Util.write_template(
                    File.join(path, '_config.yml.erb'),
                    File.join(path, '_config.yml')
                  ) do |erb|
      admin_name = Turqlom::SETTINGS['admin_name']
      admin_bm = Turqlom::SETTINGS['admin_bm']
      erb.result(binding)
    end
  end

  #jekyll build and push to s3
  def push
    Dir.chdir(path) do
      logger.info("Building blog at path: #{path}")
      `jekyll build`
      if !Turqlom::SETTINGS['disable-s3']
        logger.info("Publishing blog at path: #{path} to s3")
        `s3_website push --headless`
      end
    end
  end

  def jekyll_build
    Dir.chdir(path) do
      logger.info("Building blog at path: #{path}")
      `jekyll build`
    end
  end

  def write_post(post)
    #write post to _posts from erb template
    begin
      logger.info("Writing post #{post.file_name.gsub(/\?/, "")} to blog #{path}")
      Turqlom::Util.write_template(
                      File.join(path, '_post.md.erb'),
                      File.join(path, "_posts", post.file_name.gsub(/\?/, ""))
                    ) do |erb|
      
        layout = "post-no-feature"
        title = post.subject
        description = post.body[0..320] + ( ( post.body.size > 320 ) ? '...' : '' )
        base_url = post.base_url
        category = 'articles'
        body = post.body
        post_address = post.address
        erb.result(binding)
      end
    rescue Exception => e
      logger.error(e.backtrace)
    end

  end

  def wwwroot_path
    File.join(Turqlom::SETTINGS.wwwroot, @address)
  end

  def translate_to_web_structure
    logger.info("Creating wwwroot_path at: #{wwwroot_path}")
    FileUtils.mkdir_p(wwwroot_path)
    wwwsource_path = File.join(path, "_site/*")
    if File.directory? File.join(path, "_site")
      logger.info("Copying files from: #{wwwsource_path} to #{wwwroot_path}")
      FileUtils.cp_r(Dir.glob(wwwsource_path), wwwroot_path)
    else
      logger.error("Missing www source dir: #{wwwsource_path}")
    end
  end

  class << self
    def bm_api_client
      @@bm_api_client ||= Bitmessage::ApiClient.new Turqlom::SETTINGS.bm_uri
    end

    def import_and_publish_posts
      index_blog = Turqlom::IndexBlog.new 'www'
      index_blog.update_path
      index_blog.write_jekyll_config
      #read post fixture
      #posts = YAML.load_file(File.join(File.dirname(__FILE__),'../../test/fixtures/posts.yml'))
      #posts = posts.collect {|p| OpenStruct.new p }
      @@logger.info("Checking for messages at receiving address: #{Turqlom::SETTINGS.receiving_address}")
      posts = bm_api_client.get_all_inbox_messages.select {|m| m.to == Turqlom::SETTINGS.receiving_address }
      @@logger.info("Found #{posts.size} new messages")
      updated_blogs = []
      posts.each do |p|
        blog = Turqlom::Blog.new(p.from)
        if (updated_blogs.select { |b| b.address == blog.address }.size == 0)
          updated_blogs << blog 
          blog.update_path
          blog.write_jekyll_config
        end
        post = Turqlom::Post.new(p)
        
        blog.write_post(post)
        index_blog.write_post(post)

        # Delete message from bm
        post.delete_from_bitmessage
      end
      index_blog.jekyll_build
      index_blog.translate_to_web_structure
      updated_blogs.each do |b|
        b.jekyll_build
        b.translate_to_web_structure
      end
    end
  end
end
