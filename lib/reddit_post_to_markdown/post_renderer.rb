require "time"

module RedditPostToMarkdown
  class PostRenderer
    COLORS = ["🟩", "🟨", "🟧", "🟦", "🟪", "🟥", "🟫", "⬛️", "⬜️"].freeze

    def self.render(post_data, replies_data)
      new(post_data, replies_data).render
    end

    def initialize(post_data, replies_data)
      @post_data    = post_data
      @replies_data = replies_data
    end

    def render
      lines = []

      # Post header
      lines << "#{header_line}\n"
      lines << "## #{post_title}\n"
      lines << "Original post: [#{post_url}](#{post_url})\n"
      lines << lock_message if post_locked?

      # Selftext
      if post_selftext && !post_selftext.strip.empty?
        decoded = decode_selftext(post_selftext)
        lines << "> #{decoded.gsub("\n", "\n> ")}\n"
      end

      # Reply count + separator
      total = count_all_replies
      lines << "💬 ~ #{total} replies\n"
      lines << "---\n\n"

      # Top-level comments
      @replies_data.each do |reply_obj|
        render_top_level_reply(reply_obj, lines)
      end

      lines << "\n"
      lines.join
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

    def color_for(depth)
      COLORS[depth] || COLORS.last
    end

    def count_all_replies
      total = @replies_data.length
      @replies_data.each do |reply_obj|
        total += get_replies(reply_obj).length
      end
      total
    end

    # Recursively collects all child replies into a flat ordered hash.
    # Mirrors get_replies() from python/reddit_utils.py.
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

      color    = color_for(0)
      ups      = data.fetch("ups", 0)
      upvotes  = format_upvotes(ups)
      ts       = format_timestamp(data["created_utc"])
      ts_str   = ts ? "_( #{ts} )_" : ""
      af       = author_field(author)

      lines << "* #{color} **#{af}** #{upvotes} #{ts_str}\n\n"

      body = data.fetch("body", "")
      return if body.strip.empty?

      if body == "[deleted]"
        lines << "\tComment deleted by user\n\n"
      else
        formatted = decode_body(body)
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

      color    = color_for(cdepth)
      upvotes  = format_upvotes(ups)
      ts       = format_timestamp(child_data["created_utc"])
      ts_str   = ts ? "_( #{ts} )_" : ""
      af       = author_field(author)
      indent   = "\t" * cdepth

      lines << "#{indent}* #{color} **#{af}** #{upvotes} #{ts_str}\n\n"

      return if body.strip.empty?

      if body == "[deleted]"
        lines << "#{indent}\tComment deleted by user\n\n"
      else
        formatted = decode_child_body(body)
        formatted = linkify_mentions(formatted)
        formatted = formatted.gsub("\n", "\n#{indent}\t")
        lines << "#{indent}\t#{formatted}\n\n"
      end
    end
  end
end
