module RedditPostToMarkdown
  class UrlValidator
    PATTERNS = [
      %r{\Ahttps://(?:www\.)?reddit\.com/r/[^/]+/comments/[a-z0-9]+/},
      %r{\Ahttps://(?:www\.)?reddit\.com/[^/]+/comments/[a-z0-9]+/},
      %r{\Ahttps://(?:old\.)?reddit\.com/r/[^/]+/comments/[a-z0-9]+/},
      %r{\Ahttps://redd\.it/[a-z0-9]+}
    ].freeze

    def self.valid_post_url?(url)
      return false if url.nil? || url.empty?
      return false unless url.start_with?("https://")

      PATTERNS.any? { |pattern| url.match?(pattern) }
    end

    def self.clean_url(url)
      url = url.to_s.strip
      url = url.split("?utm_source").first
      url = url.split("?ref=").first
      url = url.split("?context=").first
      url.chomp("/")
    end
  end
end
