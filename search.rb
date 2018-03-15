require "httparty"
require "discordrb"

class SearchWrapper

  def search
    results = subreddits.map do |subreddit|
      HTTParty.get(comment_search_url(subreddit))["data"]
    end

    results.flatten
  end

  private

  def subreddits
    [
      "overwatchuniversity",
      "Competitiveoverwatch",
      "overwatch",
    ]
  end

  def comment_search_url(subreddit)
    "https://api.pushshift.io/reddit/search/comment?q=jayne&after=1d&subreddit=#{subreddit}"
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
  ]

  def initialize(attributes)
    @attributes = attributes
    @attributes.each { |k,v| instance_variable_set("@#{k}", v) }
  end

  attr_reader *SEARCH_ATTRIBUTES
end

class DiscordPoster
  def initialize(results)
    @results = results
    @bot = Discordrb::Bot.new(
      client_id: 423227495311998976,
      token: ENV["DISCORD_BOT_TOKEN"],
    )
    @bot.run :async
  end

  def post
    @bot.send_message(
      423231205752963073,
      comment_dump
    )

    @bot.sync
  end

  def comment_dump
    @results.map do |result|
      comment_format(result)
    end.join("\n")
  end

  def comment_format(search_result)
    """
    **--------------------------------------**
      **Author:** #{search_result.author}
      **Comment:** #{search_result.body}
      **Permalink:** <#{search_result.link}>
    **--------------------------------------**
    """
  end
end


search_results = SearchWrapper.new.search
parsed_results = JSONParser.new(search_results).parse
poster = DiscordPoster.new(parsed_results)

poster.post

poster.bot.stop
