require 'logger'
require 'bitmessage'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'erb'

class Turqlom::Blog
  include Logging

  S3_HOST = ".turqlom.com.s3-website-us-east-1.amazonaws.com"
  attr_accessor :address

  def initialize(address)
    @address = address
    initialize_path
  end

  def path
    File.join(Turqlom::SETTINGS.datapath, @address)
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

      Turqlom::Util.write_template(
                      File.join(path, '_s3_website.yml.erb'),
                      File.join(path, 's3_website.yml')
                    ) do |erb|
        s3_id = Turqlom::SETTINGS.s3_id
        s3_secret = Turqlom::SETTINGS.s3_secret
        s3_bucket = "#{@address.downcase}.turqlom.com"
        erb.result(binding)
      end
      
      #Set up bucket for blog
      if !Turqlom::SETTINGS['disable-s3']
        logger.info "Initializing s3 bucket for blog at path: #{path}"
        Dir.chdir(path) do
          `echo '\n' | s3_website cfg apply`
        end 
      end
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

  #update jekyll config with url
  def write_jekyll_config
    logger.info("Writing jekyll config.")
    Turqlom::Util.write_template(
                    File.join(path, '_config.yml.erb'),
                    File.join(path, '_config.yml')
                  ) do |erb|
      url = "http://#{@address.downcase}#{S3_HOST}"
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

  def write_post(post)
    #write post to _posts from erb template
    logger.info("Writing post #{post.file_name} to blog #{path}")
    Turqlom::Util.write_template(
                    File.join(path, '_post.md.erb'),
                    File.join(path, "_posts", post.file_name)
                  ) do |erb|
    
      layout = "post-no-feature"
      title = post.subject
      description = post.body[0..320] + ( ( post.body.size > 320 ) ? '...' : '' )
      base_url = "http://#{post.address.downcase}#{S3_HOST}"
      category = 'articles'
      body = post.body
      post_address = post.address
      erb.result(binding)
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
      @@logger.info("Checking for messages at receiving address: #{Turqlom::SETTINGS.receiving_address}")
      posts = bm_api_client.get_all_inbox_messages.select {|m| m.to == Turqlom::SETTINGS.receiving_address }
      @@logger.info("Found #{posts.size} new messages")
      updated_blogs = []
      posts.each do |p|
        blog = Turqlom::Blog.new(p.from)

        if (updated_blogs.keep_if { |b| b.address == blog.address }.size == 0)
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
      updated_blogs.each do |b|
        b.push
      end
      index_blog.push
    end

  end
end
