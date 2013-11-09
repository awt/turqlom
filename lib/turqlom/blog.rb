require 'logger'
require 'bitmessage'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'erb'

class Turqlom::Blog
  attr_accessor :address

  def initialize(address)
    @address = address
    initialize_path
    write_jekyll_config
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def path
    File.join(Turqlom::SETTINGS.datapath, @address)
  end

  def initialize_path
    #create address folder if it doesn't exist
    if !File.directory? path
      logger.info "Creating blog directory: #{path}"
      FileUtils.mkdir_p(path)

      #clone custom balzac repo into blog_dir
      `git clone #{Turqlom::SETTINGS.blog_template} #{path}`

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
      logger.info "Initializing s3 bucket for blog at path: #{path}"
      Dir.chdir(path) do
        `echo '\n' | s3_website cfg apply`
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
      address = @address
      url = "http://#{@address.downcase}.turqlom.com.s3-website-us-east-1.amazonaws.com"
      erb.result(binding)
    end
  end

  #jekyll build and push to s3
  def push
    logger.info("Building and publishing blog at path: #{path} to s3")
    Dir.chdir(path) do
      `jekyll build`
      `s3_website push --headless`
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
      description = 'description'
      category = 'articles'
      body = post.body
      erb.result(binding)
    end
  end

  class << self
    def bm_api_client
      @@bm_api_client ||= Bitmessage::ApiClient.new Turqlom::SETTINGS.bm_uri
    end

    def import_and_publish_posts
      index_blog = Turqlom::IndexBlog.new 'index'
      #read post fixture
      #posts = YAML.load_file(File.join(File.dirname(__FILE__),'../../test/fixtures/posts.yml'))
      updated_blogs = []
      posts = bm_api_client.get_all_inbox_messages.select {|m| m.from == Turqlom::SETTINGS.receiving_address }
      posts.each do |p|
        blog = Turqlom::Blog.new(p.from)
        updated_blogs << blog if (updated_blogs.keep_if { |b| b.address == blog.address }.size == 0)
        post = Turqlom::Post.new(p)
        
        blog.write_post(post)
        index_blog.write_post(post)

        #TODO: Delete message from bm
      end
      updated_blogs.each do |b|
        b.push
      end
      index_blog.push
    end

  end
end
