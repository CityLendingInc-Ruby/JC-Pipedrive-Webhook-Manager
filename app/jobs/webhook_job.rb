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
                  filter = [
                    "364",
                    "1172",
                    "19",
                    "3",
                    "FR0104",
                    "FR0106", 
                    "FR0107", 
                    "FR0108",
                    "11",
                    "12", 
                    "14", 
                    "15",
                    "FE0102",
                    "FE0104", 
                    "FE0105", 
                    "FE0106", 
                    "FE0107", 
                    "FE0110", 
                    "FE0117",
                    "736",
                    "356",
                    "1402",
                    "748",
                    "353",
                    "2",
                    "912"
                  ]

                  loan_fields = fields_reader(access_token, loan_guid, filter)
                  if !loan_fields.nil?
                    current_address_fields = []
                    subject_property_address_fields = []
                    employer_address_fields = []
                    loan_fields.each do |item|
                      if item["fieldId"] == "364"
                        loan_number = item["value"]
                      elsif item["fieldId"] == "19"
                        loan_purpose = item["value"]
                      elsif item["fieldId"] == "3"
                        interest_rate = item["value"]
                      elsif item["fieldId"] == "FR0104" || item["fieldId"] == "FR0106" || item["fieldId"] == "FR0107" || item["fieldId"] == "FR0108"
                        current_address_fields.push(item["value"])
                        if current_address_fields.size == 4
                          current_address = current_address_fields.join(" ")
                        end
                      elsif item["fieldId"] == "11" || item["fieldId"] == "12" || item["fieldId"] == "14" || item["fieldId"] == "15"
                        subject_property_address_fields.push(item["value"])
                        if subject_property_address_fields.size == 4
                          subject_property_address = subject_property_address_fields.join(" ")  
                        end
                      elsif item["fieldId"] == "FE0102"
                        employer_name = item["value"]
                      elsif item["fieldId"] == "FE0104" || item["fieldId"] == "FE0105" || item["fieldId"] == "FE0106" || item["fieldId"] == "FE0107" || item["fieldId"] == "FE0110" || item["fieldId"] == "FE0117"
                        employer_address_fields.push(item["value"])
                        if employer_address_fields.size == 6
                          employer_address = employer_address_fields.join(" ")
                        end
                      elsif item["fieldId"] == "736"
                        borrowers_total_income = item["value"]
                      elsif item["fieldId"] == "356"
                        appraisal_value = item["value"]
                      elsif item["fieldId"] == "1402"
                        birthday = item["value"]
                      elsif item["fieldId"] == "748"
                        closing_date = item["value"]
                      elsif item["fieldId"] == "353"
                        ltv = item["value"]
                      elsif item["fieldId"] == "2"
                        current_loan_balance = item["value"]
                      elsif item["fieldId"] == "912"
                        piti = item["value"]
                      end
                    end
                    
                    deal_id = message_as_json["deal_id"]

                    url = "https://api.pipedrive.com/v1/deals/#{deal_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
                    uri = URI.parse(url)
                    request = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
                    body = {
                      '8804ec59511693ea1a2789605ebb60634367a164': (loan_guid.nil? ? "" : loan_guid),
                      '39ef775c13d95d43807a1185aa9068a49748646d': (loan_number.nil? ? "" : loan_number),
                      'c4612b19a74ccaa46af6deb7692d83f53bb56a5c': (loan_purpose.nil? ? "" : loan_purpose),
                      'd27f00dd19b57f6edfffed557cf76592aeda93da': (loan_type.nil? ? "" : loan_type)
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

                  else
                    p "ERROR OBTAINING LOAN INFORMATION"
                  end

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