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

def loan_is_open(access_token, loan_guid)
  body = {
    customFields: [{    
        id: 'CX.ACTIVE',
        stringValue: "Y"
      },
      {    
        id: 'CX.PROJECT',
        stringValue: "JC Pipedrive Webhook Manager"
      }
    ]
  }
  
  uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}?view=id")
  request = Net::HTTP::Patch.new(uri)
  request["Authorization"] = "Bearer #{access_token}"
  request.body = JSON.dump(body)
  
  req_options = {
    use_ssl: uri.scheme == "https",
    read_timeout: 60, 
    open_timeout: 60
  }
  
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  if response.is_a?(Net::HTTPSuccess)
    p "-------------- RESPONSE ---------------"
    p response
    loan_response = JSON.parse(response.body)
    if loan_response.has_key?("id")
      false
    else
      true
    end
  else
    p "-------------- RESPONSE ---------------"
    p response
    true
  end
end

def upload_document_to_encompass(access_token, loan_guid, filename, file)
  p "AQUI 4"
  filename = filename.encode(Encoding::ASCII, invalid: :replace, undef: :replace, replace: "")
  
  messages = []
  uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}/attachments/url?view=id")
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{access_token}"
  request.body = JSON.dump({
    title: filename,
    fileWithExtension: filename,
    createReason: 4
  })
  
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  
  if response.is_a?(Net::HTTPSuccess)
    answer = JSON.parse(response.body)
    media_url = answer["mediaUrl"]
    uri = URI.parse(media_url)
    request = Net::HTTP::Put.new(uri)
    request.body = file

    req_options = {
      use_ssl: uri.scheme == "https",
    }
    
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      messages.push({status: "ok", message: "#{filename}: Attachment was uploaded successfully"})
    else
      messages.push({status: "error", message: "#{filename}: Error uploading attachment"})
    end
  else
    answer = JSON.parse(response.body)
    messages.push({status: "error", message: "#{filename}: #{answer['details']}"})
  end
  messages
end

def token_revocation(access_token)
  uri = URI.parse("https://api.elliemae.com/oauth2/v1/token/revocation")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(ENV["ENCOMPASS_CLIENT_ID"], ENV["ENCOMPASS_CLIENT_SECRET"])
  request.set_form_data(
    "token" => "#{access_token}"
  )

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  
  if response.is_a?(Net::HTTPSuccess)
    true
  else
    false
  end
end

document_id = "23946f73-e578-4628-a460-14aacf945f9f"
access_token = nil
fq = FileQueue.find(document_id)

#begin
  deal_id = fq.deal_id
  file_id = fq.file_id
  file_name = fq.file_name
  loan_guid = fq.loan_guid
  url_to_download_file = fq.url_to_download_file
  
  if access_token.nil?
    access_token = admin_access_token
  end
        
  if !access_token.nil?
    if !loan_is_open(access_token, loan_guid)
      p "AQUI 1"
      file = open(url_to_download_file+"?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}")
      file = file.read
      p "AQUI 2"
      answer = upload_document_to_encompass(access_token, loan_guid, file_name, file)
      p "AQUI 3"
      p answer
      p answer.size
      if answer.size > 0
        answer = answer[0]
        p answer
        p answer["message"]
        fq.update_attributes(comment: answer["message"], saved_encompass: true)
      else
        fq.update_attributes(comment: "ERROR UPLOADING FILE TO ENCOMPASS")
      end
    else
      fq.update_attributes(comment: "LOAN IS OPEN")
    end
  else
    fq.update_attributes(comment: "ERROR UPLOADING DOCUMENTS: MAIN USER / PASSWORD")
  end
#rescue => e
  #p e.class
  #fq.update_attributes(comment: "ERROR: " + e.class)
#end
token_revocation(access_token) unless access_token.nil?
