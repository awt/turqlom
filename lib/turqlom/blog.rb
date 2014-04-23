require 'ostruct'
require 'logger'
require 'bitmessage'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'erb'

class Turqlom::Blog
  include Logging
  include Client

  attr_accessor :address

  # Regular expression global variable used to add comments
  $comment_reg_ex = /Comment\s+@(BM-\w+)\/(\w+)/
  def initialize(address=nil)
    @address = address
    initialize_path if !address.nil?
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
        #title = post.subject
        title = post.msgid
        description = post.body[0..320] + ( ( post.body.size > 320 ) ? '...' : '' )
        base_url = post.base_url
        category = 'articles'
        body = post.body
        blog_title = post.subject
        
        # Added by deepakmani for display of timestamp
        received_at = post.received_at
         
  
        # Added by deepakmani for comment address
        msgid = post.msgid
        post_address = post.address
        #puts "Writing post " 
        erb.result(binding)
      end # of write_template method
    rescue Exception => e
      logger.error(e.message)
      logger.error(e.backtrace)
    end

  end # of write_post

  # New code to write a post in the _comments folder
  def write_comment(post)
    # for rescue
    begin
  
      #comment_reg_ex = /Comment\s+@(\w+)/
      comments_path = "#{path}/_comments"
      logger.info("Writing Comment #{post.file_name.gsub(/\?/, "")} to #{comments_path}")
  
      #puts "Comment File name" + post.file_name.gsub(/\?/, "")  
      Turqlom::Util.write_template(
                    File.join(path, '_comment.md.erb'),
                    File.join(path, "_posts/_comments", post.file_name.gsub(/\?/, ""))  
                  ) do | erb |
        base_url = post.base_url
	category = 'articles'
  	# Msg id of comment
        msgid = post.msgid       
  
        # Map msgid of the post to post_id of comment
        to_post_id = post.subject.match($comment_reg_ex)[2]      
        post_id = "/#{category}/"+ to_post_id # Jekyll::Post::id is path of the blog post by default, Config.yml defines it
        description = post.body[0..320] + (( post.body.size > 320 ) ? '...' : '' )
        address = post.address 
        received_at = post.received_at 
        erb.result(binding)
      
     end # end erb.result(binding)
  
   rescue Exception => e # why here erb.binding?
      logger.error(e.message)
      logger.error(e.backtrace)
    end  
  end # of write_comment method
 
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

  def get_messages
    #read post fixture
    if Turqlom.env == "development"
      logger.info("Loading fixtures since we're in development mode")
      posts = YAML.load_file(File.join(File.dirname(__FILE__),'../../test/fixtures/posts.yml'))
      # Take the Yaml Data and put it inside an OpenStruct 
      posts = posts.collect {|p| OpenStruct.new p }
    else
      logger.info("Checking for messages at receiving address: #{Turqlom::SETTINGS.receiving_address}")
      #puts "Receiving Address is " + Turqlom::SETTINGS.receiving_address 
      posts = bm_api_client.get_all_inbox_messages.select {|m| m.to == Turqlom::SETTINGS.receiving_address }
      puts "posts are " + posts.to_s
      logger.info("Found #{posts.size} new messages")
    end
    posts
  end

  ##These are the commands the user is able to call from the command line via options

  def reimport
    posts = []
    msgid = 0
    #iterate through folders in staging path  
    staging_path = Turqlom::SETTINGS.staging_path
    Dir.foreach(staging_path) do |blog_directory|
      next if blog_directory == '.' or blog_directory == '..' or blog_directory == 'www'
      #load each post
      Dir.foreach(File.join(staging_path, blog_directory, '_posts')) do |post_file_name|
        next if post_file_name == '.' or post_file_name == '..' or post_file_name == '.gitignore'
        post_path = File.join(staging_path, blog_directory, '_posts', post_file_name)
        metadata = YAML::load(File.read(post_path))
         
        #get body
        body = ""
        dash_count = 0
        File.open(post_path).each_line do |line|
          if (line =~ /---/) == 0
            dash_count += 1
          end
          
          if dash_count >= 2
            body += line
          end
        end
        puts "Re-importing"
        post = { msgid: msgid, message: body, from: metadata["address"], subject: metadata["title"], date: date}
        posts << post
        msgid += 1
        posts = posts.collect {|p| OpenStruct.new p }
        posts.each do |obj|
          post = Turqlom::Post.new(obj)
          post.save
        end
      end
    end
  end

  def regenerate_all
    logger.info("REGENERATE-ALL");
    posts_path = Turqlom::SETTINGS['posts_path']
    posts = []
    #iterate through all addresses
    Dir.foreach(posts_path) do |blog_directory|
      next if blog_directory == '.' or blog_directory == '..'
      #load each post
      Dir.foreach(File.join(posts_path, blog_directory)) do |post_file_name|
        next if post_file_name == '.' or post_file_name == '..'
        post_path = File.join(posts_path, blog_directory, post_file_name)
        logger.info("Regenerating from #{post_path}")
        begin
          post = JSON.parse(File.read(post_path))
        rescue
          post = eval(File.read(post_path))
        end
        posts << post
      end
    end

    posts = posts.collect {|p| OpenStruct.new p }
    publish(posts)
  end

  def regenerate(address)
    logger.info("REGENERATE");
    address.nil? && raise("No address specified to regenerate.")
    posts_path = Turqlom::SETTINGS['posts_path']
    posts = []
    blog_directory = File.join(posts_path, address)
    #load each post
    Dir.foreach(blog_directory) do |post_file_name|
      next if post_file_name == '.' or post_file_name == '..'
      post_path = File.join(blog_directory, post_file_name)
      logger.info("Regenerating from #{post_path}")
      begin
        post = JSON.parse(File.read(post_path))
      rescue
        post = eval(File.read(post_path))
      end
      posts << post
    end
    posts = posts.collect {|p| OpenStruct.new p }
    publish(posts)
  end

  def republish
    staging_path = Turqlom::SETTINGS.staging_path
    blogs = []
    Dir.foreach(staging_path) do |blog_address|
      next if blog_address == '.' or blog_address == '..' or blog_address == 'www'
      blog = Turqlom::Blog.new(blog_address)
      blogs << blog
    end

    index_blog = Turqlom::IndexBlog.new 'www'
    blogs << index_blog

    blogs.each do |blog|
      blog.update_path
      blog.jekyll_build
      blog.translate_to_web_structure
    end
  end

  def import
    publish(get_messages)
  end

  def publish(posts)

    logger.info("PUBLISH")
    index_blog = Turqlom::IndexBlog.new 'www'
    index_blog.update_path
  
    # is this needed?
    index_blog.write_jekyll_config
    updated_blogs = []
    posts.each do |p|
      # Check if the post is a comment
      isComment = !p.subject.match($comment_reg_ex).nil?
      if (isComment == true)
          # Use the address of the parent post that already exists
          # Can we hash the parent address based on msg_id?
         blog_address = p.subject.match($comment_reg_ex)[1]
      else
         blog_address = p.from
      end

      blog = Turqlom::Blog.new(blog_address)
      if (updated_blogs.select { |b| b.address == blog.address }.size == 0)
        updated_blogs << blog 
        blog.update_path
        blog.write_jekyll_config
      end

      # Take struct for each Post and use it to create a class
      post = Turqlom::Post.new(p)
      
      # Save in the data folder
      post.save 
     if (isComment == false) 
         blog.write_post(post)
        index_blog.write_post(post)
         
      
        # Delete message from bm
        post.delete_from_bitmessage
      else
       
       # Post is a comment - In parent posters path
       blog.write_comment(post)
    
       index_blog.write_comment(post)  
       post.delete_from_bitmessage
      end

    end # posts.each

    index_blog.jekyll_build
    index_blog.translate_to_web_structure
    updated_blogs.each do |b|
      b.jekyll_build
      b.translate_to_web_structure
    end # update_blogs.each
  end # publish
end # Turqlom::Blog
