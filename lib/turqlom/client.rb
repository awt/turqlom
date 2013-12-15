module Client
  # This is the magical bit that gets mixed into your classes
  def bm_api_client
    Client.bm_api_client
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.bm_api_client
    @@bm_api_client ||= Bitmessage::ApiClient.new Turqlom::SETTINGS.bm_uri
  end
end
