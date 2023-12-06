ENV["RACK_ENV"] ||= "development"
Bundler.require(:default, ENV["RACK_ENV"])

require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'

require_relative 'lib/docbase_client'
require_relative 'lib/slack_api_client'

DOCBASE_TEAM_NAME = ENV['DOCBASE_TEAM_NAME']

post '/' do
  puts "[START] #{Time.now}"
  params = JSON.parse(request.body.read)

  case params['type']
  when 'url_verification'
    # サーバの正当性検証
    challenge = params['challenge']
    return {
      challenge: challenge
    }.to_json
  when 'event_callback'
    channel = params.dig('event', 'channel')

    ts = params.dig('event', 'message_ts')
    links = params.dig('event', 'links')

    unfurls = {}
    links.each do |link|
      url = link['url']

      if url =~ /\Ahttps:\/\/#{DOCBASE_TEAM_NAME}.docbase.io\/posts\/(\d+)#comment-(\d+).*\z/
        post_number = $1
        comment_number = $2
        docbase = DocbaseClient.new
        # Not implemented, so it doesn't work yet.
        # attachment = docbase.get_comment(post_number, comment_number)
        attachment = docbase.get_post(post_number)
        unfurls[url] = attachment
      elsif url =~ /\Ahttps:\/\/#{DOCBASE_TEAM_NAME}.docbase.io\/posts\/(\d+).*\z/
        post_number = $1
        docbase = DocbaseClient.new
        attachment = docbase.get_post(post_number)
        unfurls[url] = attachment
      end
    end

    payload = {
      channel: channel,
      ts: ts,
      unfurls: unfurls
    }.to_json

    slackApiClient = SlackApiClient.new
    slackApiClient.request(payload)
  end

  return {}.to_json
end
