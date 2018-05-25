require "httparty"
require "discordrb"

class SearchWrapper

  def search
    results = subreddits.map do |subreddit|
      search_terms.map do |term|
        comments = HTTParty.get(comment_search_url(subreddit, term))["data"]
        submissions = HTTParty.get(submission_search_url(subreddit, term))["data"]

        comments + submissions
      end
    end

    results.flatten
  end

  private

  def search_terms
    [
      "deophest",
      "jayne"
    ]
  end

  def subreddits
    [
      "overwatchuniversity",
      "Competitiveoverwatch",
      "overwatch",
      "livestreamfail",
      "overwatchTMZ",
    ]
  end

  def comment_search_url(subreddit, term)
    "https://api.pushshift.io/reddit/search/comment?q=#{term}&after=1h&subreddit=#{subreddit}"
  end

  def submission_search_url(subreddit, term)
    "https://api.pushshift.io/reddit/search/submission?q=#{term}&after=1h&subreddit=#{subreddit}"
  end
end

class JSONParser

  def initialize(data)
    @data = data
  end

  def parse
    @data.map do |search_result|
      SearchResult.new(
        {
          author:    search_result["author"],
          body:      search_result["body"],
          created:   search_result["created_utc"],
          link:      "https://reddit.com#{search_result["permalink"]}",
          subreddit: search_result["subreddit"],
          title:     search_result["title"],
        }
      )
    end
  end
end

class SearchResult

  SEARCH_ATTRIBUTES = %i[
    author
    body
    created
    link
    subreddit
    title
  ]

  def initialize(attributes)
    @attributes = attributes
    @attributes.each { |k,v| instance_variable_set("@#{k}", v) }
  end

  attr_reader *SEARCH_ATTRIBUTES

  def post?
    body.nil?
  end

end

class DiscordPoster
  def initialize(results)
    @results = results
    @bot = Discordrb::Bot.new(
      client_id: 423227495311998976,
      token: ENV["DISCORD_BOT_TOKEN"],
    )
  end

  attr_accessor :bot

  def post
    comment_dump.each do |comment|
      begin
        @bot.send_message(
          446593767172997140,
          comment
        )
      rescue
        next
      end
    end
  end

  def comment_dump
    live_twitch_clip_comment = ->(result) { result.author == "LiveTwitchClips" }
    @results.reject(&live_twitch_clip_comment).map do |result|
      comment_format(result)
    end
  end

  def comment_format(search_result)
    """
      **Author:** #{search_result.author}
      **Content:** #{search_result.post? ? search_result.title : search_result.body}
      **Permalink:** <#{search_result.link}>
    """
  end
end


search_results = SearchWrapper.new.search
parsed_results = JSONParser.new(search_results).parse
poster = DiscordPoster.new(parsed_results)

poster.post

