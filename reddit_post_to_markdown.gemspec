require_relative "lib/reddit_post_to_markdown/version"

Gem::Specification.new do |spec|
  spec.name        = "reddit_post_to_markdown"
  spec.version     = RedditPostToMarkdown::VERSION
  spec.authors     = ["masukomi"]
  spec.email       = ["masukomi@masukomi.org"]
  spec.homepage    = "https://github.com/masukomi/reddit_post_to_markdown"
  spec.summary     = "Download a public Reddit post and convert it to Markdown"
  spec.description = "Takes the URL of a public Reddit post, downloads the post and its comments via the Reddit JSON API, and returns the content as a Markdown string."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.org"

  spec.files = Dir["lib/**/*.rb", "reddit_post_to_markdown.gemspec"]

  spec.add_dependency "httparty", "~> 0.22"

  spec.add_development_dependency "rspec",   "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.26"
end
