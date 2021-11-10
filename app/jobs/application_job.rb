class ApplicationJob < Jets::Job::Base
  # Adjust to increase the default timeout for all Job classes
  class_timeout 90

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

  def assign_loan_associate_milestone(access_token, loan_guid, milestone_id, loan_associate, sendToQueue = true)
    log_id = log_id(access_token, loan_guid, milestone_id)
    if log_id
      uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}/associates/#{log_id}")
      request = Net::HTTP::Put.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request.body = JSON.dump(loan_associate)
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      p "========= ASSIGN LOAN ASSOCIATE MILESTONE ========="
      p response
      
      if sendToQueue && !response.is_a?(Net::HTTPNoContent)
        response = queue_update_loan_associate(loan_guid, log_id, loan_associate)
      else
        response
      end
    else
      nil
    end
  end

  def create_loan(access_token, body)
    uri = URI.parse("https://api.elliemae.com/encompass/v1/loans?loanFolder=Prospects&view=id")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request.body = JSON.dump(body)

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      answer = JSON.parse(response.body)
      loan_guid = answer["id"]
    else
      p "---------------------------- RESPONSE -------------------------"
      p response
      p response.body
      p "---------------------------------------------------------------"
      nil
    end
  end

  def fields_reader(access_token, loan_guid, filter)
    uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}/fieldReader")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    
    request.body = JSON.dump(filter)

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      nil
    end
  end

  def loans_by_filter(access_token, filter)
    uri = URI.parse("https://api.elliemae.com/encompass/v1/loanPipeline")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request.body = JSON.dump(filter)

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
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

  def log_id(access_token, loan_guid, milestone_id)
    uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}/milestones")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    
    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    p response.body
    
    if response.is_a?(Net::HTTPSuccess)
      milestones = JSON.parse(response.body)
      milestone = milestones.select{ |ml| ml["milestoneIdString"] == milestone_id }.first
      milestone["id"]
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

  def queue_update_loan_associate(loan_guid, log_id, loan_associate)
    url = (ENV["RAILS_ENV"] == "development") ? "https://3zwq35a02b.execute-api.us-east-1.amazonaws.com/dev" : "https://yfuaoycyxl.execute-api.us-east-1.amazonaws.com/prod"
    uri = URI.parse("#{url}/update_loan_associate")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV["QUEUE_TOKEN"]}"
    request.body = JSON.dump({
      loan_guid: loan_guid,
      log_id: log_id,
      body: JSON.dump(loan_associate)
    })

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      nil
    end
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

  def upload_document_to_encompass(access_token, loan_guid, filename, contentType, size, file)
    filename = filename.encode(Encoding::ASCII, invalid: :replace, undef: :replace, replace: "")
    messages = []
    uri = URI.parse("https://api.elliemae.com/encompass/v3/loans/#{loan_guid}/attachmentUploadUrl")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request.body = JSON.dump({
      file: {
        name: filename,
        contentType: contentType,
        size: size
      },
      title: filename
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
end