require_relative "reddit_post_to_markdown/version"
require_relative "reddit_post_to_markdown/errors"
require_relative "reddit_post_to_markdown/url_validator"
require_relative "reddit_post_to_markdown/reddit_client"
require_relative "reddit_post_to_markdown/post_renderer"

module RedditPostToMarkdown
  # Downloads a Reddit post and returns it as a Markdown string.
  #
  # @param url [String] the URL of a public Reddit post
  # @param filters [Hash] optional hash to suppress comments matching any criterion:
  #   - :keywords    [Array<String>]  case-insensitive substrings; matching comments are replaced
  #   - :authors     [Array<String>]  usernames whose comments are replaced
  #   - :min_upvotes [Integer]        comments with fewer upvotes are replaced
  #   - :regexes     [Array<Regexp>]  patterns; matching comments are replaced
  #   - :message     [String]         replacement text (default: "REMOVED DUE TO CUSTOM FILTER(S)")
  # @param include_comments [Boolean] when false, omits all comments from the output (default: true)
  # @return [String] the post and all its comments rendered as Markdown
  # @raise [NotAPostError] if the URL does not point to a Reddit post
  # @raise [FetchError] if the HTTP request fails
  # @raise [InvalidResponseError] if Reddit returns an unexpected JSON structure
  def self.convert(url, filters: {}, include_comments: true)
    clean = UrlValidator.clean_url(url)

    unless UrlValidator.valid_post_url?(clean)
      raise NotAPostError, "Not a Reddit post URL: #{url}"
    end

    data = RedditClient.new.fetch_post(clean)

    post_info = data.dig(0, "data", "children")
    raise InvalidResponseError, "No post data found in response" if post_info.nil? || post_info.empty?

    post_data    = post_info[0].fetch("data", {})
    replies_data = include_comments ? (data.dig(1, "data", "children") || []) : []

    PostRenderer.render(post_data, replies_data, filters: filters)
  end
end
