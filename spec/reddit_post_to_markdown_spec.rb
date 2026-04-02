require "spec_helper"
require "reddit_post_to_markdown"

RSpec.describe RedditPostToMarkdown do
  let(:post_url) { "https://www.reddit.com/r/ruby/comments/abc123/some_title" }

  let(:reddit_response) do
    [
      {
        "data" => {
          "children" => [
            {
              "data" => {
                "title"                   => "Some Title",
                "author"                  => "op_user",
                "subreddit_name_prefixed" => "r/ruby",
                "selftext"                => "",
                "url"                     => post_url,
                "ups"                     => 100,
                "locked"                  => false,
                "created_utc"             => 1_640_995_200
              }
            }
          ]
        }
      },
      {
        "data" => {
          "children" => [
            {
              "data" => {
                "author"      => "commenter",
                "body"        => "Great post!",
                "ups"         => 5,
                "depth"       => 0,
                "id"          => "c1",
                "created_utc" => 1_640_995_260,
                "replies"     => ""
              }
            }
          ]
        }
      }
    ]
  end

  before do
    stub_request(:get, "#{post_url}.json")
      .to_return(
        status: 200,
        body: reddit_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe ".convert" do
    it "returns a String" do
      expect(described_class.convert(post_url)).to be_a(String)
    end

    it "returns markdown containing the post title" do
      expect(described_class.convert(post_url)).to include("## Some Title")
    end

    it "returns markdown containing a top-level comment" do
      expect(described_class.convert(post_url)).to include("Great post!")
    end

    it "cleans the URL before using it (strips utm_source)" do
      dirty_url = "#{post_url}/?utm_source=share"
      # same stub applies because clean_url strips the query string + trailing slash
      expect(described_class.convert(dirty_url)).to include("## Some Title")
    end

    it "raises NotAPostError for a subreddit listing URL" do
      expect { described_class.convert("https://www.reddit.com/r/ruby/") }
        .to raise_error(RedditPostToMarkdown::NotAPostError)
    end

    it "raises NotAPostError for a non-reddit URL" do
      expect { described_class.convert("https://example.com/something") }
        .to raise_error(RedditPostToMarkdown::NotAPostError)
    end

    it "raises NotAPostError for an http (non-https) URL" do
      expect { described_class.convert("http://www.reddit.com/r/ruby/comments/abc123/title/") }
        .to raise_error(RedditPostToMarkdown::NotAPostError)
    end

    it "raises FetchError when Reddit returns a non-2xx response" do
      stub_request(:get, "#{post_url}.json").to_return(status: 503, body: "Service Unavailable")
      expect { described_class.convert(post_url) }
        .to raise_error(RedditPostToMarkdown::FetchError)
    end

    it "raises InvalidResponseError when response is not a 2-element array" do
      stub_request(:get, "#{post_url}.json")
        .to_return(
          status: 200,
          body: { "error" => 403 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      expect { described_class.convert(post_url) }
        .to raise_error(RedditPostToMarkdown::InvalidResponseError)
    end
  end
end
