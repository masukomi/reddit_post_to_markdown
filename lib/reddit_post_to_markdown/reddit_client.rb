require "httparty"

module RedditPostToMarkdown
  class RedditClient
    include HTTParty

    USER_AGENT = "RedditMarkdownConverter/1.0 (Safe Download Bot)"

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
