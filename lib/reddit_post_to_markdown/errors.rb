module RedditPostToMarkdown
  # Raised when the given URL does not match a Reddit post URL pattern
  class NotAPostError < StandardError; end

  # Raised when the HTTP request to Reddit fails
  class FetchError < StandardError; end

  # Raised when Reddit returns an unexpected JSON structure
  class InvalidResponseError < StandardError; end
end
