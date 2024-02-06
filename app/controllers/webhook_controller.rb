require 'line/bot'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          text = "飲み会中の会話に困ったときトークテーマを提供します！\n「話題」とか「トークテーマ」で送ってみてね！"
          if event.message['text'].include?("題") || event.message['text'].include?("テーマ") then
            text = combine_word
          end
          message = {
            type: 'text',
            text: text
          }
          client.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Location
          res_text = search_shop(event.message['latitude'], event.message['longitude'])
          message = {
            "type": "template",
            "altText": "おすすめのお店情報が届きました！",
            "template": {
              "type": "carousel",
              "columns": res_text,
              "imageAspectRatio": "rectangle",
              "imageSize": "cover"
            }
          }
          p message
          client.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Location
          res_text = search_shop(event.message['latitude'], event.message['longitude'])
          message = {
            "type": "template",
            "altText": "おすすめのお店情報が届きました！",
            "template": {
              "type": "carousel",
              "columns": res_text,
              "imageAspectRatio": "rectangle",
              "imageSize": "cover"
            }
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }
    head :ok
  end


  private
  hotpepper_api = "http://webservice.recruit.co.jp/hotpepper/gourmet/v1/".freeze

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  
  def search_shop(lat, lng)
    uri = URI.parse("http://webservice.recruit.co.jp/hotpepper/gourmet/v1/")
    http = Net::HTTP.new(uri.host, uri.port) 
    # hotpepper apiのパラメータ
    # range 3: 1000m以内
    # genre G001:居酒屋, G002:ダイニングバー・バル
    # budget B002:2001~3000円, B003:3001~4000円
    uri.query = URI.encode_www_form({
        key: ENV["API_KEY"],
        lat: lat,
        lng: lng,
        range: 3,
        genre: "G001,G002",
        budget: "B002,B003",
        order: 4,
        format: 'json'
    })

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      columns = []
      data["results"]["shop"].each do |shop|
        content = {
          thumbnailImageUrl: shop["photo"]["mobile"]["l"],
          title: shop["name"],
          text: shop["address"],
          actions: [{
            type: "uri",
            label: "詳細を見る",
            uri: shop["urls"]["pc"]
          }]
        }
        columns.push(content)
      end
      columns
    else
      p "リクエストが失敗しました。ステータスコード: #{response.code}"
    end
  end
  
  def combine_word
    five_w = ["いつ", "どこで", "なぜ", "どのように"]
    object_word = ["食べ物を", "飲み物を", "スポーツを", "趣味を", "仕事を", "恋愛を", "家族を", "友達を", "学校を", "旅行を"]
    varb_word = [ "しますか", "見ますか", "聞きますか", "話しますか", "考えますか", "感じますか"]
    five_w.sample + object_word.sample + varb_word.sample
  end


end
