module RedditPostToMarkdown
  # Raised when the given URL does not match a Reddit post URL pattern.
  # This includes subreddit listings, user profiles, search results, and
  # any URL that is not a direct link to a single post.
  class NotAPostError < StandardError; end

  # Raised when the HTTP request to Reddit fails with a non-2xx status code.
  class FetchError < StandardError; end

  # Raised when Reddit returns a response that does not have the expected
  # two-element JSON array structure of a post listing.
  class InvalidResponseError < StandardError; end
end
