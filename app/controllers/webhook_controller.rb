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
          message = {
            type: 'text',
            text: event.message['text']
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
    uri = URI.parse(hotpepper_api)
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
    # p uri
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

end
