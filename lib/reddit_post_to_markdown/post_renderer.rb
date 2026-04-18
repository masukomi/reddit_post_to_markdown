require "time"

module RedditPostToMarkdown
  # Converts Reddit post data and its comments into a Markdown string.
  #
  # The output format matches the {https://github.com/chauduyphanvu/reddit-markdown
  # reddit-markdown} tool: post header, title, selftext, reply count, and a
  # depth-indented comment tree.
  class PostRenderer
    # Replacement text used when a comment matches a filter and no custom
    # +:message+ is provided in the filters hash.
    DEFAULT_FILTERED_MESSAGE = "REMOVED DUE TO CUSTOM FILTER(S)"

    # Renders a Reddit post and its comments as a Markdown string.
    #
    # This is the primary entry point for the class. It instantiates a renderer
    # and calls {#render}.
    #
    # @param post_data [Hash] the +data+ object from Reddit's post listing JSON,
    #   containing keys such as +"title"+, +"author"+, +"selftext"+, +"ups"+,
    #   +"locked"+, +"created_utc"+, and +"subreddit_name_prefixed"+
    # @param replies_data [Array<Hash>] the +children+ array from Reddit's
    #   comment listing JSON; each element represents a top-level comment
    # @param filters [Hash] optional comment filters (see {RedditPostToMarkdown.convert}
    #   for full key documentation)
    # @return [String] the fully rendered Markdown
    def self.render(post_data, replies_data, filters: {})
      new(post_data, replies_data, filters).render
    end

    # @param post_data [Hash] Reddit post data hash (see {.render})
    # @param replies_data [Array<Hash>] top-level comment objects (see {.render})
    # @param filters [Hash] optional comment filters (see {.render})
    def initialize(post_data, replies_data, filters = {})
      @post_data    = post_data
      @replies_data = replies_data
      @filters      = filters || {}
    end

    # Renders the post and all its comments as a single Markdown string.
    #
    # Sections in order:
    # 1. Post header (subreddit, author, upvotes, timestamp)
    # 2. Post title as an H2
    # 3. Link back to the original post
    # 4. Lock notice (if the thread is locked)
    # 5. Post body / selftext as a block-quote (if present)
    # 6. Total reply count
    # 7. Horizontal rule
    # 8. Comment tree, depth-indented with tab characters
    #
    # @return [String]
    def render
      lines = []

      # Post header
      lines << "#{header_line}"
      lines << "## #{post_title}"
      lines << "Original post: [#{post_url}](#{post_url})"
      lines << lock_message if post_locked?

      # Selftext
      if post_selftext && !post_selftext.strip.empty?
        decoded = decode_selftext(post_selftext)
        lines << "> #{decoded.gsub("\n", "\n> ")}"
      end

      image_urls = post_image_urls()
      if image_urls.size > 0
        lines << "### Images"
        image_urls.each do |url|
          lines << "![no alt text](#{url})"
        end
        lines << ""
      end

      # Reply count + separator
      total = count_all_replies
      lines << "💬 ~ #{total} replies"
      lines << "---\n"

      # Top-level comments
      @replies_data.each do |reply_obj|
        render_top_level_reply(reply_obj, lines)
      end

      lines.join("\n")
    end

    private

    def post_title
      @post_data.fetch("title", "Untitled")
    end

    def post_author
      @post_data.fetch("author", "[unknown]")
    end

    def post_subreddit
      @post_data.fetch("subreddit_name_prefixed", "")
    end

    def post_ups
      @post_data.fetch("ups", 0)
    end

    def post_locked?
      @post_data.fetch("locked", false)
    end

    def post_selftext
      @post_data.fetch("selftext", "")
    end

    def post_url
      @post_data.fetch("url", "")
    end

    def post_created_utc
      @post_data["created_utc"]
    end

    def post_image_urls
      image_urls = []
      media_metadata = @post_data["media_metadata"]
      # a hash of hashes with some sort of hashed keys we don't care about
      return image_urls unless media_metadata
      media_metadata.each do |_hashed_key, metadata_hash|
        next unless metadata_hash["e"] == "Image" || metadata_hash["e"] == "AnimatedImage"
        src = metadata_hash["s"]
        next unless src
        url = src["u"] || src["gif"] || src["mp4"]
        next unless url
        # Reddit JSON HTML-encodes query strings; strip the signed params and
        # rewrite preview.redd.it → i.redd.it so the URL serves the image directly
        # instead of redirecting to an HTML wrapper page.
        url = url.gsub("&amp;", "&").split("?")[0].sub("/preview.", "/i.")
        image_urls << url
      end
      image_urls
    end

    def header_line
      upvotes = format_upvotes(post_ups)
      ts      = format_timestamp(post_created_utc)
      ts_str  = ts ? "_( #{ts} )_" : ""
      "**#{post_subreddit}** | Posted by u/#{post_author} #{upvotes} #{ts_str}"
    end

    def lock_message
      "---\n\n>🔒 **This thread has been locked by the moderators of #{post_subreddit}**.\n  New comments cannot be posted\n\n"
    end

    def format_upvotes(ups)
      return "" if ups.nil?
      ups >= 1000 ? "⬆️ #{ups / 1000}k" : "⬆️ #{ups}"
    end

    def format_timestamp(utc)
      return nil unless utc && utc != 0
      Time.at(utc.to_i).utc.strftime("%Y-%m-%d %H:%M:%S")
    rescue
      nil
    end

    def decode_selftext(text)
      text
        .gsub("&amp;", "&")
        .gsub("&lt;", "<")
        .gsub("&gt;", ">")
        .gsub("&quot;", '"')
    end

    def apply_filter(author, body, ups)
      return body if @filters.nil? || @filters.empty?

      message    = @filters[:message]     || DEFAULT_FILTERED_MESSAGE
      keywords   = Array(@filters[:keywords])
      authors    = Array(@filters[:authors])
      min_ups    = @filters[:min_upvotes] || 0
      regexes    = Array(@filters[:regexes])

      keywords.each do |kw|
        return message if body.downcase.include?(kw.to_s.downcase)
      end

      return message if authors.include?(author)
      return message if ups < min_ups

      regexes.each do |regex|
        return message if regex.match?(body)
      end

      body
    end

    def decode_body(text)
      text
        .gsub("&gt;", ">")
        .gsub("\r", "")
    end

    def decode_child_body(text)
      text
        .gsub("&gt;", ">")
        .gsub("&amp;#32;", " ")
        .gsub("^^[", "[")
        .gsub("^^(", "(")
    end

    def linkify_mentions(text)
      text.gsub(%r{u/(\w+)}) { "[u/#{$1}](https://www.reddit.com/user/#{$1})" }
    end

    def author_link(author)
      return author if author.nil? || author == "[deleted]" || author.empty?
      "[#{author}](https://www.reddit.com/user/#{author})"
    end

    def author_field(author)
      field = author_link(author)
      field += " (OP)" if author == post_author && author != "[deleted]" && !author.empty?
      field
    end

    def count_all_replies
      total = @replies_data.length
      @replies_data.each do |reply_obj|
        total += get_replies(reply_obj).length
      end
      total
    end

    # Recursively collects all child replies into a flat ordered hash.
    #
    # Traverses the Reddit comment tree depth-first and returns every
    # descendant comment keyed by its Reddit comment ID. Comments with empty
    # or whitespace-only bodies are skipped. Comments deeper than +max_depth+
    # are skipped unless +max_depth+ is +-1+ (unlimited).
    #
    # @param reply_data [Hash] a Reddit comment object containing a nested
    #   +"replies"+ structure
    # @param max_depth [Integer] maximum comment depth to collect;
    #   +-1+ means no limit
    # @param collected [Hash] accumulator used during recursion; callers
    #   should omit this argument
    # @return [Hash{String => Hash}] a hash of
    #   +id => { depth: Integer, child_reply: Hash }+ in depth-first order
    def get_replies(reply_data, max_depth: -1, collected: {})
      replies_obj = reply_data.dig("data", "replies")
      return collected unless replies_obj.is_a?(Hash)

      children = replies_obj.dig("data", "children") || []
      children.each do |child|
        child_data  = child.fetch("data", {})
        child_id    = child_data["id"]
        child_depth = child_data.fetch("depth", 0)
        child_body  = child_data.fetch("body", "")

        next if max_depth != -1 && child_depth > max_depth
        next if child_body.strip.empty?

        collected[child_id] = { depth: child_depth, child_reply: child }
        get_replies(child, max_depth: max_depth, collected: collected)
      end

      collected
    end

    def render_top_level_reply(reply_obj, lines)
      data   = reply_obj.fetch("data", {})
      author = data.fetch("author", "")

      return if author.empty?
      return if author == "AutoModerator"

      ups      = data.fetch("ups", 0)
      upvotes  = format_upvotes(ups)
      ts       = format_timestamp(data["created_utc"])
      ts_str   = ts ? "_( #{ts} )_" : ""
      af       = author_field(author)

      lines << "* **#{af}** #{upvotes} #{ts_str}\n\n"

      body = data.fetch("body", "")
      return if body.strip.empty?

      if body == "[deleted]"
        lines << "\tComment deleted by user\n\n"
      else
        filtered  = apply_filter(author, body, ups)
        formatted = decode_body(filtered)
        formatted = linkify_mentions(formatted)
        formatted = formatted.gsub("\n", "\n\t")
        lines << "\t#{formatted}\n\n"
      end

      # Nested replies
      child_map = get_replies(reply_obj)
      child_map.each_value do |info|
        render_child_reply(info, lines)
      end
    end

    def render_child_reply(info, lines)
      cdepth      = info[:depth]
      child_data  = info[:child_reply].fetch("data", {})
      author      = child_data.fetch("author", "")
      ups         = child_data.fetch("ups", 0)
      body        = child_data.fetch("body", "")

      upvotes  = format_upvotes(ups)
      ts       = format_timestamp(child_data["created_utc"])
      ts_str   = ts ? "_( #{ts} )_" : ""
      af       = author_field(author)
      indent   = "\t" * cdepth

      lines << "#{indent}* **#{af}** #{upvotes} #{ts_str}\n\n"

      return if body.strip.empty?

      if body == "[deleted]"
        lines << "#{indent}\tComment deleted by user\n\n"
      else
        filtered  = apply_filter(author, body, ups)
        formatted = decode_child_body(filtered)
        formatted = linkify_mentions(formatted)
        formatted = formatted.gsub("\n", "\n#{indent}\t")
        lines << "#{indent}\t#{formatted}\n\n"
      end
    end
  end
end
