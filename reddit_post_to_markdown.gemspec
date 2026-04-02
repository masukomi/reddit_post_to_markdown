require_relative "lib/reddit_post_to_markdown/version"

Gem::Specification.new do |spec|
  spec.name        = "reddit_post_to_markdown"
  spec.version     = RedditPostToMarkdown::VERSION
  spec.authors     = ["masukomi"]
  spec.summary     = "Download a public Reddit post and convert it to Markdown"
  spec.description = "Takes the URL of a public Reddit post, downloads the post and its comments via the Reddit JSON API, and returns the content as a Markdown string."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 2.7"

  spec.files = Dir["lib/**/*.rb", "reddit_post_to_markdown.gemspec"]

  spec.add_dependency "httparty", "~> 0.22"

  spec.add_development_dependency "rspec",   "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.26"
end
