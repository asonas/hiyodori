require 'net/http'
require 'json'
require 'time'

class DocbaseClient
  DOCBASE_ACCESS_TOKEN = ENV['DOCBASE_ACCESS_TOKEN']

  DOCBASE_MAX_ARTICLE_LINES = ENV.fetch('DOCBASE_MAX_ARTICLE_LINES', '10').to_i
  DOCBASE_MAX_COMMENT_LINES = ENV.fetch('DOCBASE_MAX_COMMENT_LINES', '10').to_i

  DESIRED_SCOPE = ENV['DESIRED_SCOPE'] || ''

  def initialize
    @http = Net::HTTP.new('api.docbase.io', 443)
    @http.use_ssl = true
  end

  def get_post(post_number)
    req = Net::HTTP::Get.new("/teams/#{DOCBASE_TEAM_NAME}/posts/#{post_number}")
    req.add_field('X-DocBaseToken', DOCBASE_ACCESS_TOKEN)
    res = @http.request(req)
    post = JSON.parse(res.body)

    title = post['title']
    footer = generate_footer(post)

    payload = {
      title: unescape(title),
      title_link: post['url'],
      author_name: post['user']['name'],
      author_icon: post['user']['profile_image_url'],
      text: article_text(post),
      color: '#00B9C1',
      footer: footer,
      ts: Time.parse(post['updated_at']).to_i
    }

    if !DESIRED_SCOPE.empty? && DESIRED_SCOPE == post['scope']
      payload = {}
    end

    return payload
  end

  def get_comment(post_number, comment_number)
    cache_json = @cache.get("comment-#{comment_number}")
    unless cache_json.nil?
      puts '[LOG] cache hit'
      cache = JSON.parse(cache_json)
      return cache['info']
    end

    post = @esa_client.post(post_number, {include: "comments"}).body
    return {} if post.nil?

    comment = nil
    post['comments'].each do |c|
      if c['id'] == comment_number.to_i
        comment = c
        break
      end
    end

    if comment.nil?
      comment = @esa_client.comment(comment_number).body
    end
    return {} if comment.nil?

    post_name = post['full_name']
    post_name.insert(0, '[WIP] ') if post['wip']
    title = "#{post_name} へのコメント"
    footer = generate_footer(comment)
    info = {
      title: title,
      title_link: comment['url'],
      author_name: comment['created_by']['screen_name'],
      author_icon: comment['created_by']['icon'],
      text: comment_text(comment),
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(comment['updated_at']).to_i
    }

    @cache.set("comment-#{comment_number}", info)
    return info
  end

  private
  def article_text(post)
    unescape(post['body'].lines[0, DOCBASE_MAX_ARTICLE_LINES].map{ |item| item.chomp }.join("\n"))
  end

  def comment_text(comment)
    unescape(comment['body'].lines[0, DOCBASE_MAX_COMMENT_LINES].map{ |item| item.chomp }.join("\n"))
  end

  def unescape(str)
    str.gsub('&#35;', '#').gsub('&#47;', '/')
  end

  def generate_footer(post)
    created_user_name = post.dig('user', 'name') || 'unknown'
    return "Created by #{created_user_name}"
  end
end
