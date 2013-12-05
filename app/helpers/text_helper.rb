module TextHelper
  DEFAULT_TRUNCATED_URL_LENGTH = 65.freeze
  DEFAULT_TRUNCATED_HTML_LENGTH = 150.freeze
  DEFAULT_TRUNCATE_OPTIONS = { length_in_chars: true, ellipsis: ' ...' }

  def url_without_protocol(url)
    url.gsub(%r[^https?://]i, '') if url.present?
  end

  def truncate_url(url, truncation_length = DEFAULT_TRUNCATED_URL_LENGTH)
    Truncator::UrlParser.shorten_url(url, truncation_length) if url.present?
  end

  def truncate_html(html, max_length = DEFAULT_TRUNCATED_HTML_LENGTH, options = {})
    return '' unless html
    HTML_Truncator.truncate(html, max_length, options.reverse_merge(DEFAULT_TRUNCATE_OPTIONS)).html_safe
  end
end
