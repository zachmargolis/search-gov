class CachedSearchApiConnection
  attr_reader :connection

  def initialize(namespace, site, cache_duration = 60 * 60 * 6)
    @connection = Faraday.new site do |conn|
      conn.request :json
      conn.response :rashify
      conn.response :json
      conn.headers[:user_agent] = 'USASearch'
      conn.adapter :net_http_persistent
    end
    @cache = ApiCache.new namespace, cache_duration
  end

  protected

  def cache_response(api_endpoint, param_hash, response)
    if response.status == 200
      @cache.write api_endpoint, param_hash, response
    end
  end
end