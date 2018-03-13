require "httparty"
require "discordrb"

class SearchWrapper

  def search
    results = subreddits.map do |subreddit|
      HTTParty.get(comment_search_url(subreddit))["data"]
    end

    results.flatten
  end

  def parse(results)
    JSONParser.new(results).parse
  end

  def post_to_discord(results)
    DiscordPoster.new(results).post
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
          link:      search_result["permalink"],
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
      token: ENV["DISCORD_API_SECRET"],
    )
  end

  def post
    @bot.send_message(
      423231205752963073,
      comment_dump
    )
  end

  def comment_dump
    @results.map do |result|
      comment_format(result)
    end.join("\n")
  end

  def comment_format(search_result)
    """
    --------------------------------------
      Author: #{search_result.author} \n

      Comment: #{search_result.body} \n

      Permalink: #{search_result.link} \n

      Subreddit: #{search_result.subreddit}
    --------------------------------------
    """
  end
end

wrapper = SearchWrapper.new

search_results = wrapper.search
parsed_results = wrapper.parse(search_results)
wrapper.post_to_discord(parsed_results)

