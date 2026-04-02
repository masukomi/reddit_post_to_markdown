require "spec_helper"
require "reddit_post_to_markdown/url_validator"

RSpec.describe RedditPostToMarkdown::UrlValidator do
  describe ".valid_post_url?" do
    context "valid post URLs" do
      it "accepts www.reddit.com /r/ post" do
        expect(described_class.valid_post_url?(
          "https://www.reddit.com/r/ruby/comments/abc123/some_title/"
        )).to be true
      end

      it "accepts reddit.com without www" do
        expect(described_class.valid_post_url?(
          "https://reddit.com/r/python/comments/def456/title/"
        )).to be true
      end

      it "accepts old.reddit.com" do
        expect(described_class.valid_post_url?(
          "https://old.reddit.com/r/programming/comments/abc123/title/"
        )).to be true
      end

      it "accepts redd.it short URLs" do
        expect(described_class.valid_post_url?("https://redd.it/abc123")).to be true
      end

      it "accepts URLs without a trailing slash" do
        expect(described_class.valid_post_url?(
          "https://www.reddit.com/r/ruby/comments/abc123/some_title"
        )).to be true
      end

      it "accepts URLs with a longer path after the post ID" do
        expect(described_class.valid_post_url?(
          "https://www.reddit.com/r/ruby/comments/abc123/title/extra"
        )).to be true
      end
    end

    context "invalid URLs" do
      it "rejects a subreddit listing page" do
        expect(described_class.valid_post_url?("https://www.reddit.com/r/ruby/")).to be false
      end

      it "rejects the reddit homepage" do
        expect(described_class.valid_post_url?("https://www.reddit.com/")).to be false
      end

      it "rejects a non-reddit URL" do
        expect(described_class.valid_post_url?("https://example.com/foo")).to be false
      end

      it "rejects http (non-https)" do
        expect(described_class.valid_post_url?(
          "http://www.reddit.com/r/ruby/comments/abc123/title/"
        )).to be false
      end

      it "rejects nil" do
        expect(described_class.valid_post_url?(nil)).to be false
      end

      it "rejects empty string" do
        expect(described_class.valid_post_url?("")).to be false
      end
    end
  end

  describe ".clean_url" do
    it "strips ?utm_source and everything after" do
      url = "https://www.reddit.com/r/ruby/comments/abc123/title/?utm_source=share&utm_medium=web"
      expect(described_class.clean_url(url)).to eq(
        "https://www.reddit.com/r/ruby/comments/abc123/title"
      )
    end

    it "strips ?ref= parameters" do
      url = "https://www.reddit.com/r/ruby/comments/abc123/title/?ref=rss"
      expect(described_class.clean_url(url)).to eq(
        "https://www.reddit.com/r/ruby/comments/abc123/title"
      )
    end

    it "strips ?context= parameters" do
      url = "https://www.reddit.com/r/ruby/comments/abc123/title/?context=3"
      expect(described_class.clean_url(url)).to eq(
        "https://www.reddit.com/r/ruby/comments/abc123/title"
      )
    end

    it "strips trailing slash" do
      url = "https://www.reddit.com/r/ruby/comments/abc123/title/"
      expect(described_class.clean_url(url)).to eq(
        "https://www.reddit.com/r/ruby/comments/abc123/title"
      )
    end

    it "leaves a clean URL unchanged (except trailing slash)" do
      url = "https://www.reddit.com/r/ruby/comments/abc123/title"
      expect(described_class.clean_url(url)).to eq(url)
    end

    it "strips leading/trailing whitespace" do
      url = "  https://www.reddit.com/r/ruby/comments/abc123/title  "
      expect(described_class.clean_url(url)).to eq(
        "https://www.reddit.com/r/ruby/comments/abc123/title"
      )
    end
  end
end
