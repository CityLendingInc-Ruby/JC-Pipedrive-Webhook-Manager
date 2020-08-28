class ApplicationJob < Jets::Job::Base
  # Adjust to increase the default timeout for all Job classes
  class_timeout 60

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
      use_ssl: uri.scheme == "https",
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
      nil
    end
  end

  def fields_reader(access_token, loan_guid, filter)
    uri = URI.parse("https://api.elliemae.com/encompass/v1/loans/#{loan_guid}/fieldReader")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    #request.body = "['364','1172','19','3','FR0104','FR0106','FR0107','FR0108','11','12','14','15','FE0102','FE0104','FE0105','FE0106','FE0107','FE0110','FE0117','736','356','1402','748','353','2','912']"
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
      p response
      p response.body
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
end