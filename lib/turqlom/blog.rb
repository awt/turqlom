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
                        File.join(post.blog_path, 's3_website.yml.erb'),
                        File.join(post.blog_path, 's3_website.yml')
                      ) do |erb|
          s3_bucket = "#{post.address}.turqlom.com"
          erb.result(binding)
        end
        #`s3_website cfg apply`
      end
      #write post to _posts from erb template
      write_template(
                      File.join(post.blog_path, 'post.md.erb'),
                      File.join(post.blog_path, "_posts", post.file_name)
                    ) do |erb|
      
        layout = "post-no-feature"
        title = post.subject
        description = 'description'
        category = 'article'
        body = post.body
        erb.result(binding)
      end

      #jekyll build

      `jekyll build`
      #post to s3 website
      #s3_website cfg apply
      #s3_website push --headless
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
