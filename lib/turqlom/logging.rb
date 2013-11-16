module Logging
  # This is the magical bit that gets mixed into your classes
  def logger
    Logging.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    log_file_path = File.join(File.dirname(__FILE__),'../../logs/turqlom.log')
    @@logger ||= Logger.new(log_file_path, 'daily')
  end
end
