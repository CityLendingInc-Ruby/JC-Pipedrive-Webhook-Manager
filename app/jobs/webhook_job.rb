class WebhookJob < ApplicationJob
  class_timeout 90

  sns_event "jc-pipedrive-webhook-manager-job-processing"
  def process
    records = event["Records"]
    if records.size > 0
      p "Records Size: #{records.size}"
      item = records[0]
      message = item["Sns"]["Message"]
      message_as_json = JSON.parse(message)
      is_bulk_update = message_as_json["is_bulk_update"]
      encompass_loan_number = message_as_json["encompass_loan_number"]

      if !is_bulk_update && encompass_loan_number.blank?
        name_lastname = message_as_json["name_lastname"]
        person_id = message_as_json["person_id"]
        stage_id = message_as_json["stage_id"]
        
        url = "https://api.pipedrive.com/v1/stages/#{stage_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
                
        uri = URI.parse(url)
        request = Net::HTTP::Get.new(uri)
        
        req_options = {
          use_ssl: uri.scheme == "https",
        }
        
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
        
        if response.is_a?(Net::HTTPSuccess)
          answer = JSON.parse(response.body)
          data = answer["data"]
          if data["name"] == "Pipeline"
            url = "https://api.pipedrive.com/v1/persons/#{person_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
            uri = URI.parse(url)
            request = Net::HTTP::Get.new(uri)
            
            req_options = {
              use_ssl: uri.scheme == "https",
            }
            
            response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
              http.request(request)
            end
            
            if response.is_a?(Net::HTTPSuccess)
              answer = JSON.parse(response.body)
              data = answer["data"]
              phones = data["phone"]
              emails = data["email"]

              items = name_lastname.split(" ")

              if items.size > 1
                name = items[0]
                lastname = items[1...items.size].join(" ")
              else
                name = name_lastname
                lastname = ""
              end

              phone = phones.size > 0 ? phones[0]["value"] : ""
              email = emails.size > 0 ? emails[0]["value"] : ""

              # CREATING THE LOAN IN ENCOMPASS
              access_token = admin_access_token
                            
              if !access_token.nil?
                body = {
                  applicationTakenMethodType: "Internet",
                  applications: [{
                    borrower: {
                      firstName: name,
                      lastName: lastname,
                      emailAddressText: email,
                      homePhoneNumber: phone

                    }
                  }]
                }
                loan_guid = create_loan(access_token, body)

                if !loan_guid.nil?
                  filter = {
                    filter: {
                      operator: "and",
                      terms: [
                        {
                          canonicalName: "Fields.GUID",
                          value: loan_guid,
                          matchType: "exact",
                          include: true
                        }
                      ]
                    },
                    fields: [
                      "Fields.364"
                    ]
                  }
=begin
                  loans = loans_by_filter(access_token, filter)
                  if !loans.nil? and !loans.first.nil?
                    loan = loans.first
                                        
                    loan_number = loan["fields"]["Fields.364"]
=end
                    loan_number = loan_guid
                    deal_id = message_as_json["deal_id"]

                    url = "https://api.pipedrive.com/v1/deals/#{deal_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
                    uri = URI.parse(url)
                    request = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
                    body = {
                      '39ef775c13d95d43807a1185aa9068a49748646d': loan_number
                    }
                    request.body = JSON.dump(body)

                    req_options = {
                      use_ssl: uri.scheme == "https",
                    }
                    
                    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
                      http.request(request)
                    end
                    
                    if response.is_a?(Net::HTTPSuccess)
                      p "EVERYTHING CREATED AND UPDATED"
                    else
                      p "ERROR UPDATING DEAL ON PIPEDRIVE"
                      p response
                      p response.body
                    end
=begin
                  else
                    p "ERROR OBTAINING LOAN INFORMATION"
                  end
=end
                else
                  p "ERROR CREATING LOAN"
                end

                token_revocation(access_token)
              else
                p "ERROR OBTAINING ACCESS TOKEN"
              end
            else
              p "ERROR REQUESTING PERSON INFORMATION FROM PIPEDRIVE"    
            end    
          end
        else
          p "ERROR REQUESTING STAGE INFORMATION FROM PIPEDRIVE"
        end
      end
    end
  end
end