def admin_access_token
  username = ENV["ADMIN_USERNAME"]
  password = ENV["ADMIN_PASSWORD"]

  uri = URI.parse("https://api.elliemae.com/oauth2/v1/token")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(ENV["ENCOMPASS_CLIENT_ID"], ENV["ENCOMPASS_CLIENT_SECRET"])
  request.set_form_data(
    "grant_type" => "password",
    "password" => "#{password}",
    "username" => "#{username}@encompass:#{ENV["ENCOMPASS_INSTANCE"]}"
  )

  req_options = {
    use_ssl: uri.scheme == "https"
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if response.is_a?(Net::HTTPSuccess)
    answer = JSON.parse(response.body)
    admin_user_access_token = answer["access_token"]
  else
    nil
  end
end

def open_file(url)
  url = URI(url)
  Net::HTTP.start(url.host) do |http|
    resp = http.get(url.path)
  end
end

def loan_is_open(access_token, loan_guid)
  body = {
    customFields: [{    
        id: 'CX.ACTIVE',
        stringValue: "Y"
      },
      {    
        id: 'CX.PROJECT',
        stringValue: "Upload Documents"
      }
    ]
  }
  
  uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}?view=id")
  request = Net::HTTP::Patch.new(uri)
  request["Authorization"] = "Bearer #{access_token}"
  request.body = JSON.dump(body)
  
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  if response.is_a?(Net::HTTPSuccess)
    loan_response = JSON.parse(response.body)
    if loan_response.has_key?("id")
      false
    else
      true
    end
  else
    true
  end
end


loan_guid = "6082c09e-9d19-466b-a5be-fc7edf9c95a0"
pipedrive_file_id = "13971"

url = "https://api.pipedrive.com/v1/files/#{pipedrive_file_id}/download?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
url_2 = "https://pipedrive-files.s3-eu-west-1.amazonaws.com/WhatsApp-Image-2020-09-14-at-11.25.09-AM-July_7394875112129956296c78615a027408bf90a68aa432d33.jpeg?response-content-disposition=filename%3D%22WhatsApp%20Image%202020-09-14%20at%2011.25.09%20AM%20July.jpeg%22&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAXBWJG2HXWQXJX6FZ%2F20200916%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20200916T021100Z&X-Amz-SignedHeaders=Host&X-Amz-Expires=3600&X-Amz-Signature=03ae63d91509650d5b8361c76e78f7ca8bb48d0d23a53b9f14456c98a2fec715"
file = open(url)

p file