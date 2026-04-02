require "spec_helper"
require "reddit_post_to_markdown/errors"
require "reddit_post_to_markdown/reddit_client"

RSpec.describe RedditPostToMarkdown::RedditClient do
  subject(:client) { described_class.new }

  let(:valid_response) do
    [
      { "data" => { "children" => [{ "data" => { "title" => "Test Post" } }] } },
      { "data" => { "children" => [] } }
    ]
  end

  describe "#fetch_post" do
    context "when request succeeds" do
      it "appends .json to the URL and returns parsed data" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_return(
            status: 200,
            body: valid_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title")
        expect(result).to eq(valid_response)
      end

      it "does not double-append .json if already present" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_return(
            status: 200,
            body: valid_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title.json")
        expect(result).to eq(valid_response)
      end

      it "sends the correct User-Agent header" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .with(headers: { "User-Agent" => "RedditMarkdownConverter/1.0 (Safe Download Bot)" })
          .to_return(
            status: 200,
            body: valid_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .not_to raise_error
      end
    end

    context "when request fails" do
      it "raises FetchError on non-2xx response" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_return(status: 404, body: "Not Found")

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .to raise_error(RedditPostToMarkdown::FetchError, /404/)
      end

      it "raises FetchError on 500 response" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_return(status: 500, body: "Server Error")

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .to raise_error(RedditPostToMarkdown::FetchError)
      end

      it "propagates network-level errors (e.g. connection refused)" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_raise(SocketError.new("Failed to connect"))

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .to raise_error(SocketError)
      end

      it "propagates timeout errors" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_raise(Net::OpenTimeout.new("execution expired"))

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .to raise_error(Net::OpenTimeout)
      end
    end

    context "when response is structurally invalid" do
      it "raises InvalidResponseError when response is not an array" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_return(
            status: 200,
            body: { "error" => "not a post" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .to raise_error(RedditPostToMarkdown::InvalidResponseError)
      end

      it "raises InvalidResponseError when array has fewer than 2 elements" do
        stub_request(:get, "https://www.reddit.com/r/ruby/comments/abc123/title.json")
          .to_return(
            status: 200,
            body: [valid_response[0]].to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect { client.fetch_post("https://www.reddit.com/r/ruby/comments/abc123/title") }
          .to raise_error(RedditPostToMarkdown::InvalidResponseError)
      end
    end
  end
end
