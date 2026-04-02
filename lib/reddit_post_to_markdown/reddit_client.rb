require "httparty"

module RedditPostToMarkdown
  # Fetches Reddit post JSON via the public Reddit API.
  #
  # Requests are made without authentication using Reddit's +.json+ endpoint,
  # which is available for any public post.
  class RedditClient
    include HTTParty

    USER_AGENT = "RedditMarkdownConverter/1.0 (Safe Download Bot)"

    # Downloads the JSON data for a Reddit post URL.
    #
    # Appends +.json+ to +url+ (unless already present) and issues a GET
    # request. Reddit returns a two-element array: the first element contains
    # the post data and the second contains the top-level comments.
    #
    # @param url [String] a cleaned Reddit post URL (no trailing slash,
    #   no query parameters)
    # @return [Array] the parsed two-element JSON response from Reddit
    # @raise [FetchError] if the server returns a non-2xx HTTP status
    # @raise [InvalidResponseError] if the parsed response is not a two-element
    #   Array
    def fetch_post(url)
      json_url = url.end_with?(".json") ? url : "#{url}.json"

      response = self.class.get(json_url, headers: { "User-Agent" => USER_AGENT })

      raise FetchError, "HTTP #{response.code} fetching #{url}" unless response.success?

      data = response.parsed_response

      unless data.is_a?(Array) && data.length >= 2
        raise InvalidResponseError, "Expected a 2-element JSON array from #{url}"
      end

      data
    end
  end
end
