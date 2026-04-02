require_relative "reddit_post_to_markdown/version"
require_relative "reddit_post_to_markdown/errors"
require_relative "reddit_post_to_markdown/url_validator"
require_relative "reddit_post_to_markdown/reddit_client"
require_relative "reddit_post_to_markdown/post_renderer"

# Top-level namespace for the reddit_post_to_markdown gem.
module RedditPostToMarkdown
  # Downloads a public Reddit post and returns it as a Markdown string.
  #
  # The URL must point directly to a single post. Subreddit listings, user
  # profiles, search pages, and similar URLs will raise {NotAPostError}.
  # Posts that require authentication (private subreddits, age-gated content)
  # are not accessible.
  #
  # @example Basic usage
  #   markdown = RedditPostToMarkdown.convert(
  #     "https://www.reddit.com/r/ruby/comments/abc123/some_title/"
  #   )
  #
  # @example Without comments
  #   markdown = RedditPostToMarkdown.convert(url, include_comments: false)
  #
  # @example With comment filters
  #   markdown = RedditPostToMarkdown.convert(
  #     url,
  #     filters: {
  #       keywords:    ["spam"],
  #       authors:     ["AutoModerator"],
  #       min_upvotes: 5,
  #       regexes:     [/buy now/i],
  #       message:     "[ removed ]"
  #     }
  #   )
  #
  # @param url [String] the URL of a public Reddit post
  # @param include_comments [Boolean] when +false+, omits all comments and
  #   renders only the post header, title, body, and a reply count of 0.
  #   Defaults to +true+.
  # @param filters [Hash] optional hash to suppress comments matching any
  #   criterion. Filters are evaluated in the order listed below; the first
  #   match replaces the comment body with +:message+. All keys are optional.
  # @option filters [Array<String>] :keywords case-insensitive substrings;
  #   any comment whose body contains one of these strings is replaced
  # @option filters [Array<String>] :authors usernames (exact, case-sensitive
  #   match) whose comments are replaced regardless of content
  # @option filters [Integer] :min_upvotes comments with fewer upvotes than
  #   this value are replaced
  # @option filters [Array<Regexp>] :regexes patterns matched against the
  #   comment body; a match causes the comment to be replaced
  # @option filters [String] :message the replacement text used when any
  #   filter matches (default: +"REMOVED DUE TO CUSTOM FILTER(S)"+)
  # @return [String] the post and its comments rendered as Markdown
  # @raise [NotAPostError] if +url+ does not point to a Reddit post
  # @raise [FetchError] if the HTTP request to Reddit fails
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
