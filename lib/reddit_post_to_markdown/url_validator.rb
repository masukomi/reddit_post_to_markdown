module RedditPostToMarkdown
  # Validates and normalises Reddit post URLs.
  class UrlValidator
    PATTERNS = [
      %r{\Ahttps://(?:www\.)?reddit\.com/r/[^/]+/comments/[a-z0-9]+/},
      %r{\Ahttps://(?:www\.)?reddit\.com/[^/]+/comments/[a-z0-9]+/},
      %r{\Ahttps://(?:old\.)?reddit\.com/r/[^/]+/comments/[a-z0-9]+/},
      %r{\Ahttps://redd\.it/[a-z0-9]+}
    ].freeze

    # Returns +true+ if +url+ looks like a direct Reddit post URL.
    #
    # A valid post URL must use HTTPS and match one of the following forms:
    # - +https://www.reddit.com/r/<sub>/comments/<id>/+
    # - +https://reddit.com/r/<sub>/comments/<id>/+
    # - +https://old.reddit.com/r/<sub>/comments/<id>/+
    # - +https://redd.it/<id>+
    #
    # Subreddit listings, user profiles, search pages, and similar URLs return
    # +false+.
    #
    # @param url [String, nil] the URL to check
    # @return [Boolean]
    def self.valid_post_url?(url)
      return false if url.nil? || url.empty?
      return false unless url.start_with?("https://")

      PATTERNS.any? { |pattern| url.match?(pattern) }
    end

    # Strips the query string and trailing slash from a Reddit URL.
    #
    # Removes everything from the first +?+ onward (tracking params, share IDs,
    # etc. are never needed to fetch the post JSON), then strips any trailing
    # slash. Leading and trailing whitespace is also removed.
    #
    # @param url [String] the URL to clean
    # @return [String] the cleaned URL
    def self.clean_url(url)
      url = url.to_s.strip
      url = url.split("?").first
      url.chomp("/")
    end
  end
end
