require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'erb'

class Turqlom::Blog
  def self.import_and_publish_posts
    #read post fixture
    posts = YAML.load_file(File.join(File.dirname(__FILE__),'../../test/fixtures/posts.yml'))
    posts.each do |p|
      post = Turqlom::Post.new(p)

      #create address folder if it doesn't exist
      if !File.directory? post.blog_path
        FileUtils.mkdir_p(post.blog_path)

        #clone custom balzac repo into blog_dir
        `git clone --verbose git@github.com:awt/Balzac-for-Jekyll.git #{post.blog_path}`

        write_template(
                        File.join(post.blog_path, '_s3_website.yml.erb'),
                        File.join(post.blog_path, 's3_website.yml')
                      ) do |erb|
          s3_bucket = "#{post.address.downcase}.turqlom.com"
          erb.result(binding)
        end
        
        #Set up bucket for blog
        Dir.chdir(post.blog_path) do
          `echo '\n' | s3_website cfg apply`
        end 
      end
      
      #write post to _posts from erb template
      write_template(
                      File.join(post.blog_path, '_post.md.erb'),
                      File.join(post.blog_path, "_posts", post.file_name)
                    ) do |erb|
      
        layout = "post-no-feature"
        title = post.subject
        description = 'description'
        category = 'articles'
        body = post.body
        erb.result(binding)
      end

      #update jekyll config with url
      write_template(
                      File.join(post.blog_path, '_config.yml.erb'),
                      File.join(post.blog_path, '_config.yml')
                    ) do |erb|
        address = post.address
        url = "http://#{post.address.downcase}.turqlom.com.s3-website-us-east-1.amazonaws.com"
        erb.result(binding)
      end

      #jekyll build and push to s3
      Dir.chdir(post.blog_path) do
        `jekyll build`
        `s3_website push --headless`
      end
    end
  end

  def self.write_template(in_path, out_path, &block)
    template = File.new(in_path).read
    erb = ERB.new template, nil, '%'
    File.open(out_path, 'w+') do |file|
      file.write(yield erb)
    end
  end
end
