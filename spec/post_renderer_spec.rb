require "spec_helper"
require "reddit_post_to_markdown/post_renderer"

RSpec.describe RedditPostToMarkdown::PostRenderer do
  # Helpers to build minimal Reddit JSON-shaped hashes

  def make_post(overrides = {})
    {
      "title"                    => "Test Post Title",
      "author"                   => "op_user",
      "subreddit_name_prefixed"  => "r/ruby",
      "selftext"                 => "",
      "url"                      => "https://www.reddit.com/r/ruby/comments/abc123/test_post_title/",
      "ups"                      => 42,
      "locked"                   => false,
      "created_utc"              => 1_640_995_200 # 2022-01-01 00:00:00 UTC
    }.merge(overrides)
  end

  def make_comment(overrides = {})
    {
      "data" => {
        "author"       => "commenter",
        "body"         => "This is a comment.",
        "ups"          => 10,
        "depth"        => 0,
        "id"           => "c1",
        "created_utc"  => 1_640_995_260, # 2022-01-01 00:01:00 UTC
        "replies"      => ""
      }.merge(overrides)
    }
  end

  def make_child(id:, depth:, body:, author: "child_user", ups: 5, replies: "")
    {
      "data" => {
        "author"      => author,
        "body"        => body,
        "ups"         => ups,
        "depth"       => depth,
        "id"          => id,
        "created_utc" => 1_640_995_320,
        "replies"     => replies
      }
    }
  end

  def nested_replies(*children)
    { "data" => { "children" => children } }
  end

  subject(:output) { described_class.render(post_data, replies_data) }

  let(:post_data)    { make_post }
  let(:replies_data) { [] }

  # ─── Post header ────────────────────────────────────────────────────────────

  describe "post header" do
    it "includes the subreddit" do
      expect(output).to include("**r/ruby**")
    end

    it "includes the author" do
      expect(output).to include("Posted by u/op_user")
    end

    it "formats upvotes below 1000 as a plain number" do
      expect(output).to include("⬆️ 42")
    end

    it "formats upvotes >= 1000 with k suffix (integer division)" do
      post_data = make_post("ups" => 1_500)
      out = described_class.render(post_data, [])
      expect(out).to include("⬆️ 1k")
    end

    it "formats upvotes of exactly 1000 as 1k" do
      post_data = make_post("ups" => 1_000)
      out = described_class.render(post_data, [])
      expect(out).to include("⬆️ 1k")
    end

    it "formats upvotes of 9999 as 9k" do
      post_data = make_post("ups" => 9_999)
      out = described_class.render(post_data, [])
      expect(out).to include("⬆️ 9k")
    end

    it "includes the UTC timestamp wrapped in _( )_" do
      expect(output).to include("_( 2022-01-01 00:00:00 )_")
    end
  end

  # ─── Post title ─────────────────────────────────────────────────────────────

  describe "post title" do
    it "renders as an h2" do
      expect(output).to include("## Test Post Title\n")
    end
  end

  # ─── Original post link ─────────────────────────────────────────────────────

  describe "original post link" do
    it "includes a markdown link to the post URL" do
      url = "https://www.reddit.com/r/ruby/comments/abc123/test_post_title/"
      expect(output).to include("Original post: [#{url}](#{url})")
    end
  end

  # ─── Selftext ────────────────────────────────────────────────────────────────

  describe "selftext" do
    it "is omitted when empty" do
      expect(output).not_to match(/^> /)
    end

    it "is blockquoted when present" do
      post_data = make_post("selftext" => "Hello world")
      out = described_class.render(post_data, [])
      expect(out).to include("> Hello world\n")
    end

    it "preserves multiple lines with > prefix on each" do
      post_data = make_post("selftext" => "Line one\nLine two")
      out = described_class.render(post_data, [])
      expect(out).to include("> Line one\n> Line two\n")
    end

    it "decodes HTML entities in selftext" do
      post_data = make_post("selftext" => "AT&amp;T &lt;rocks&gt; &quot;yeah&quot;")
      out = described_class.render(post_data, [])
      expect(out).to include('> AT&T <rocks> "yeah"')
    end
  end

  # ─── Lock message ────────────────────────────────────────────────────────────

  describe "lock message" do
    it "is omitted when post is not locked" do
      expect(output).not_to include("🔒")
    end

    it "is included when post is locked" do
      post_data = make_post("locked" => true)
      out = described_class.render(post_data, [])
      expect(out).to include("🔒 **This thread has been locked by the moderators of r/ruby**")
    end
  end

  # ─── Reply count ─────────────────────────────────────────────────────────────

  describe "reply count" do
    it "shows zero when there are no comments" do
      expect(output).to include("💬 ~ 0 replies")
    end

    it "counts top-level comments" do
      replies = [make_comment("id" => "c1"), make_comment("id" => "c2")]
      out = described_class.render(post_data, replies)
      expect(out).to include("💬 ~ 2 replies")
    end

    it "counts nested comments in the total" do
      child = make_child(id: "c2", depth: 1, body: "nested")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("💬 ~ 2 replies")
    end
  end

  # ─── Separator ───────────────────────────────────────────────────────────────

  describe "separator" do
    it "includes a --- after the reply count" do
      expect(output).to include("💬 ~ 0 replies\n---\n\n")
    end
  end

  # ─── Top-level comments ──────────────────────────────────────────────────────

  describe "top-level comments" do
    let(:replies_data) { [make_comment] }

    it "renders with green square color indicator" do
      expect(output).to include("* 🟩 **")
    end

    it "renders author as a link" do
      expect(output).to include("[commenter](https://www.reddit.com/user/commenter)")
    end

    it "renders body indented with a single tab" do
      expect(output).to include("\tThis is a comment.")
    end

    it "renders the comment timestamp" do
      expect(output).to include("_( 2022-01-01 00:01:00 )_")
    end

    it "renders upvotes" do
      expect(output).to include("⬆️ 10")
    end

    it "marks OP comments with (OP)" do
      comment = make_comment("author" => "op_user")
      out = described_class.render(post_data, [comment])
      expect(out).to include("op_user](https://www.reddit.com/user/op_user) (OP)")
    end

    it "renders [deleted] author without a link" do
      comment = make_comment("author" => "[deleted]")
      out = described_class.render(post_data, [comment])
      expect(out).to include("**[deleted]**")
      expect(out).not_to include("[deleted](https://www.reddit.com")
    end

    it "renders deleted body as 'Comment deleted by user'" do
      comment = make_comment("body" => "[deleted]")
      out = described_class.render(post_data, [comment])
      expect(out).to include("\tComment deleted by user")
    end

    it "skips AutoModerator comments" do
      comment = make_comment("author" => "AutoModerator")
      out = described_class.render(post_data, [comment])
      expect(out).not_to include("AutoModerator")
    end

    it "skips comments with empty body (but still renders header)" do
      comment = make_comment("body" => "   ")
      out = described_class.render(post_data, [comment])
      expect(out).to include("* 🟩 **")
      expect(out).not_to include("\t ")
    end

    it "decodes &gt; in comment body" do
      comment = make_comment("body" => "check &gt; this")
      out = described_class.render(post_data, [comment])
      expect(out).to include("\tcheck > this")
    end

    it "strips \\r from comment body" do
      comment = make_comment("body" => "line1\r\nline2")
      out = described_class.render(post_data, [comment])
      expect(out).not_to include("\r")
    end

    it "replaces newlines in body with newline + tab" do
      comment = make_comment("body" => "line1\nline2")
      out = described_class.render(post_data, [comment])
      expect(out).to include("\tline1\n\tline2")
    end

    it "converts u/username mentions to links" do
      comment = make_comment("body" => "thanks u/someone for this")
      out = described_class.render(post_data, [comment])
      expect(out).to include("[u/someone](https://www.reddit.com/user/someone)")
    end

    it "converts multiple u/username mentions in a single body" do
      comment = make_comment("body" => "Hey u/test_user, great post! Also ping u/another_user")
      out = described_class.render(post_data, [comment])
      expect(out).to include("[u/test_user](https://www.reddit.com/user/test_user)")
      expect(out).to include("[u/another_user](https://www.reddit.com/user/another_user)")
    end
  end

  # ─── Nested comments ─────────────────────────────────────────────────────────

  describe "nested comments" do
    let(:child_depth1) do
      make_child(id: "c2", depth: 1, body: "depth 1 reply", author: "child1", ups: 3)
    end
    let(:top_comment) do
      make_comment("id" => "c1", "replies" => nested_replies(child_depth1))
    end
    let(:replies_data) { [top_comment] }

    it "renders depth-1 child with yellow square color" do
      expect(output).to include("\t* 🟨 **")
    end

    it "indents depth-1 child header with one tab" do
      expect(output).to match(/^\t\* 🟨/)
    end

    it "indents depth-1 child body with two tabs" do
      expect(output).to include("\t\tdepth 1 reply")
    end

    it "renders depth-1 child author as a link" do
      expect(output).to include("[child1](https://www.reddit.com/user/child1)")
    end

    context "depth 2 nesting" do
      let(:grandchild) do
        make_child(id: "c3", depth: 2, body: "depth 2 reply", author: "child2")
      end
      let(:child_with_replies) do
        make_child(id: "c2", depth: 1, body: "depth 1", author: "child1",
                   replies: nested_replies(grandchild))
      end
      let(:top_comment) do
        make_comment("id" => "c1", "replies" => nested_replies(child_with_replies))
      end

      it "renders depth-2 child with orange square color" do
        expect(output).to include("\t\t* 🟧 **")
      end

      it "indents depth-2 child body with three tabs" do
        expect(output).to include("\t\t\tdepth 2 reply")
      end
    end

    context "deeply nested (depth 5+)" do
      let(:deep_child) do
        make_child(id: "c6", depth: 5, body: "deep", author: "deep_user")
      end

      it "uses 🟥 for depth 5" do
        top = make_comment("id" => "c1", "replies" => nested_replies(deep_child))
        out = described_class.render(post_data, [top])
        expect(out).to include("* 🟥 **")
      end
    end

    it "converts u/username mentions in child body to links" do
      child = make_child(id: "c2", depth: 1, body: "thanks u/another")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("[u/another](https://www.reddit.com/user/another)")
    end

    it "decodes &gt; in child body" do
      child = make_child(id: "c2", depth: 1, body: "x &gt; y")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("x > y")
    end

    it "decodes &amp;#32; as space in child body" do
      child = make_child(id: "c2", depth: 1, body: "a&amp;#32;b")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("a b")
    end

    it "strips bot signature carets from child body" do
      child = make_child(id: "c2", depth: 1, body: "see ^^[link](url) and ^^(note)")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("[link](url)")
      expect(out).to include("(note)")
      expect(out).not_to include("^^")
    end

    it "renders deleted child body as 'Comment deleted by user'" do
      child = make_child(id: "c2", depth: 1, body: "[deleted]")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("\t\tComment deleted by user")
    end

    it "marks OP replies in nested comments with (OP)" do
      child = make_child(id: "c2", depth: 1, body: "OP replies", author: "op_user")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out   = described_class.render(post_data, [top])
      expect(out).to include("op_user](https://www.reddit.com/user/op_user) (OP)")
    end
  end

  # ─── Filters ─────────────────────────────────────────────────────────────────

  describe "#apply_filter" do
    subject(:renderer) { described_class.new(post_data, [], filters) }

    let(:message) { "REMOVED DUE TO CUSTOM FILTER(S)" }

    context "with no filters" do
      let(:filters) { {} }

      it "returns the original body unchanged" do
        expect(renderer.send(:apply_filter, "user", "hello world", 10)).to eq("hello world")
      end
    end

    context "keyword filter" do
      let(:filters) { { keywords: ["spam"] } }

      it "replaces body containing the keyword (case-insensitive)" do
        expect(renderer.send(:apply_filter, "user", "This is SPAM content", 10))
          .to eq(message)
      end

      it "replaces body with keyword in mixed case" do
        expect(renderer.send(:apply_filter, "user", "Spam spam spam", 10))
          .to eq(message)
      end

      it "leaves body without the keyword unchanged" do
        expect(renderer.send(:apply_filter, "user", "totally normal comment", 10))
          .to eq("totally normal comment")
      end

      it "matches keyword as a substring" do
        expect(renderer.send(:apply_filter, "user", "nospamhere", 10))
          .to eq(message)
      end
    end

    context "author filter" do
      let(:filters) { { authors: ["bot_account", "spammer"] } }

      it "replaces comments from a filtered author" do
        expect(renderer.send(:apply_filter, "bot_account", "hello", 10))
          .to eq(message)
      end

      it "leaves comments from non-filtered authors unchanged" do
        expect(renderer.send(:apply_filter, "normal_user", "hello", 10))
          .to eq("hello")
      end

      it "is case-sensitive for author names" do
        expect(renderer.send(:apply_filter, "Bot_Account", "hello", 10))
          .to eq("hello")
      end
    end

    context "min_upvotes filter" do
      let(:filters) { { min_upvotes: 5 } }

      it "replaces comments with fewer upvotes than the minimum" do
        expect(renderer.send(:apply_filter, "user", "low score comment", 3))
          .to eq(message)
      end

      it "leaves comments that meet the minimum upvotes unchanged" do
        expect(renderer.send(:apply_filter, "user", "ok comment", 5))
          .to eq("ok comment")
      end

      it "leaves comments above the minimum upvotes unchanged" do
        expect(renderer.send(:apply_filter, "user", "popular comment", 100))
          .to eq("popular comment")
      end
    end

    context "regex filter" do
      let(:filters) { { regexes: [/buy now/i, /\bfree\b/] } }

      it "replaces body matching a regex pattern" do
        expect(renderer.send(:apply_filter, "user", "Click here to Buy Now!", 10))
          .to eq(message)
      end

      it "replaces body matching a second regex" do
        expect(renderer.send(:apply_filter, "user", "get it for free today", 10))
          .to eq(message)
      end

      it "leaves body not matching any regex unchanged" do
        expect(renderer.send(:apply_filter, "user", "just a normal comment", 10))
          .to eq("just a normal comment")
      end
    end

    context "custom message" do
      let(:filters) { { keywords: ["bad"], message: "[HIDDEN]" } }

      it "uses the custom filtered_message when provided" do
        expect(renderer.send(:apply_filter, "user", "this is bad content", 10))
          .to eq("[HIDDEN]")
      end
    end

    context "default filtered message" do
      let(:filters) { { keywords: ["spam"] } }

      it "uses the default message when none is provided" do
        expect(renderer.send(:apply_filter, "user", "spam", 10))
          .to eq("REMOVED DUE TO CUSTOM FILTER(S)")
      end
    end

    context "filter precedence" do
      let(:filters) { { keywords: ["bad"], authors: ["baduser"], min_upvotes: 3, message: "NOPE" } }

      it "keywords are checked first" do
        expect(renderer.send(:apply_filter, "gooduser", "bad content", 100)).to eq("NOPE")
      end

      it "authors are checked after keywords" do
        expect(renderer.send(:apply_filter, "baduser", "good content", 100)).to eq("NOPE")
      end

      it "upvotes are checked after authors" do
        expect(renderer.send(:apply_filter, "gooduser", "good content", 1)).to eq("NOPE")
      end
    end
  end

  describe "filters applied during rendering" do
    let(:filters) { { keywords: ["hidden"], min_upvotes: 5, authors: ["banned"] } }

    it "replaces a top-level comment body matching a keyword" do
      comment = make_comment("body" => "this is hidden content")
      out = described_class.render(post_data, [comment], filters: filters)
      expect(out).to include("REMOVED DUE TO CUSTOM FILTER(S)")
      expect(out).not_to include("this is hidden content")
    end

    it "replaces a nested comment body matching a keyword" do
      child = make_child(id: "c2", depth: 1, body: "hidden spam here")
      top   = make_comment("id" => "c1", "replies" => nested_replies(child))
      out = described_class.render(post_data, [top], filters: filters)
      expect(out).to include("REMOVED DUE TO CUSTOM FILTER(S)")
    end

    it "replaces a top-level comment below the min_upvotes threshold" do
      comment = make_comment("body" => "low karma comment", "ups" => 2)
      out = described_class.render(post_data, [comment], filters: filters)
      expect(out).to include("REMOVED DUE TO CUSTOM FILTER(S)")
      expect(out).not_to include("low karma comment")
    end

    it "replaces a top-level comment from a banned author" do
      comment = make_comment("author" => "banned", "body" => "I am banned")
      out = described_class.render(post_data, [comment], filters: filters)
      expect(out).to include("REMOVED DUE TO CUSTOM FILTER(S)")
      expect(out).not_to include("I am banned")
    end

    it "does not filter a [deleted] body (handled separately)" do
      comment = make_comment("body" => "[deleted]")
      out = described_class.render(post_data, [comment], filters: { keywords: ["deleted"] })
      expect(out).to include("Comment deleted by user")
      expect(out).not_to include("REMOVED DUE TO CUSTOM FILTER(S)")
    end

    it "leaves comments alone when no filter matches" do
      comment = make_comment("body" => "perfectly fine comment", "ups" => 10)
      out = described_class.render(post_data, [comment], filters: filters)
      expect(out).to include("perfectly fine comment")
    end
  end

  # ─── get_replies (recursive child collector) ────────────────────────────────

  describe "#get_replies" do
    subject(:renderer) { described_class.new(post_data, []) }

    it "returns an empty hash when the reply has no children" do
      reply = make_comment("replies" => "")
      expect(renderer.send(:get_replies, reply)).to eq({})
    end

    it "returns an empty hash when replies field is nil" do
      reply = make_comment("replies" => nil)
      expect(renderer.send(:get_replies, reply)).to eq({})
    end

    it "collects direct children keyed by their id" do
      child = make_child(id: "c2", depth: 1, body: "child body")
      reply = make_comment("id" => "c1", "replies" => nested_replies(child))
      result = renderer.send(:get_replies, reply)
      expect(result.keys).to eq(["c2"])
      expect(result["c2"][:depth]).to eq(1)
      expect(result["c2"][:child_reply]).to eq(child)
    end

    it "skips children with empty or whitespace-only bodies" do
      empty_child  = make_child(id: "empty", depth: 1, body: "   ")
      normal_child = make_child(id: "normal", depth: 1, body: "hello")
      reply = make_comment("replies" => nested_replies(empty_child, normal_child))
      result = renderer.send(:get_replies, reply)
      expect(result.keys).to eq(["normal"])
    end

    it "collects grandchildren recursively" do
      grandchild = make_child(id: "gc", depth: 2, body: "grandchild")
      child      = make_child(id: "c2", depth: 1, body: "child",
                               replies: nested_replies(grandchild))
      reply = make_comment("replies" => nested_replies(child))
      result = renderer.send(:get_replies, reply)
      expect(result.keys).to contain_exactly("c2", "gc")
      expect(result["gc"][:depth]).to eq(2)
    end

    it "preserves depth-first insertion order" do
      gc1   = make_child(id: "gc1",  depth: 2, body: "grandchild 1")
      gc2   = make_child(id: "gc2",  depth: 2, body: "grandchild 2")
      child1 = make_child(id: "c1", depth: 1, body: "child 1",
                           replies: nested_replies(gc1, gc2))
      child2 = make_child(id: "c2", depth: 1, body: "child 2")
      reply = make_comment("replies" => nested_replies(child1, child2))
      result = renderer.send(:get_replies, reply)
      expect(result.keys).to eq(["c1", "gc1", "gc2", "c2"])
    end

    it "respects max_depth and skips children deeper than the limit" do
      deep = make_child(id: "deep", depth: 3, body: "too deep")
      mid  = make_child(id: "mid",  depth: 2, body: "ok depth",
                         replies: nested_replies(deep))
      top  = make_child(id: "top",  depth: 1, body: "top child",
                         replies: nested_replies(mid))
      reply = make_comment("replies" => nested_replies(top))
      result = renderer.send(:get_replies, reply, max_depth: 2)
      expect(result.keys).to contain_exactly("top", "mid")
      expect(result.keys).not_to include("deep")
    end

    it "collects all depths when max_depth is -1 (unlimited)" do
      deep = make_child(id: "d4", depth: 4, body: "very deep")
      l3   = make_child(id: "d3", depth: 3, body: "level 3", replies: nested_replies(deep))
      l2   = make_child(id: "d2", depth: 2, body: "level 2", replies: nested_replies(l3))
      l1   = make_child(id: "d1", depth: 1, body: "level 1", replies: nested_replies(l2))
      reply = make_comment("replies" => nested_replies(l1))
      result = renderer.send(:get_replies, reply, max_depth: -1)
      expect(result.keys).to contain_exactly("d1", "d2", "d3", "d4")
    end
  end

  # ─── Full output structure ───────────────────────────────────────────────────

  describe "full output structure" do
    it "ends with a trailing newline" do
      expect(output).to end_with("\n")
    end

    it "renders sections in order: header, title, link, replies, separator, comments" do
      post_data  = make_post("selftext" => "body text")
      comment    = make_comment
      out        = described_class.render(post_data, [comment])
      header_pos    = out.index("**r/ruby**")
      title_pos     = out.index("## Test Post Title")
      link_pos      = out.index("Original post:")
      selftext_pos  = out.index("> body text")
      count_pos     = out.index("💬")
      separator_pos = out.index("---")
      comment_pos   = out.index("* 🟩")

      expect(header_pos).to be < title_pos
      expect(title_pos).to  be < link_pos
      expect(link_pos).to   be < selftext_pos
      expect(selftext_pos). to be < count_pos
      expect(count_pos).to  be < separator_pos
      expect(separator_pos).to be < comment_pos
    end
  end
end
