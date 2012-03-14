class NewsSearch < Search
  attr_reader :rss_feed,
              :related_search,
              :hits,
              :since,
              :spelling_suggestion

  def initialize(options = {})
    super(options)
    @query = (@query || '').squish
    @since = since_when(options[:tbs])
    @rss_feed = @affiliate.rss_feeds.find_by_id(options[:channel].to_i) if options[:channel].present?
    @related_search, @hits, @total = [], [], 0
  end

  def search
    rss_feeds = @rss_feed ? [@rss_feed] : @affiliate.rss_feeds.navigable_only
    NewsItem.search_for(@query, rss_feeds, @since, @page)
  end

  def handle_response(response)
    if response
      @results = response.results
      @hits = response.hits
      @total = response.total
      @related_search = SaytSuggestion.related_search(@query, @affiliate)
    end
  end

  def has_related_searches?
    @related_search && @related_search.size > 0
  end

  private

  def since_when(tbs)
    if tbs && (extent = NewsItem::TIME_BASED_SEARCH_OPTIONS[tbs])
      1.send(extent).ago
    end
  end

  def log_serp_impressions
    modules = []
    modules << "NEWS" unless @total.zero?
    modules << "SREL" unless @related_search.nil? or @related_search.empty?
    QueryImpression.log(:news, @affiliate.name, @query, modules)
  end
end