# Encoding: utf-8
class WebhookJob < ApplicationJob
  class_timeout 90
  
  sns_event "jc-pipedrive-webhook-manager-job-processing"
  def process
    records = event["Records"]
    if records.size > 0
      p "Records Size: #{records.size}"
      item = records[0]
      message = item["Sns"]["Message"]
      
      if ENV["JETS_ENV"] == "production"
        message_as_json = JSON.parse(message)
      else
        message_as_json = message
      end
      
      stage_ids = ["3","8","10"]
      is_bulk_update = message_as_json["is_bulk_update"]
      encompass_loan_guid = message_as_json["encompass_loan_guid"]
      deal_id = message_as_json["deal_id"]
      name_lastname = message_as_json["name_lastname"]
      person_id = message_as_json["person_id"]
      files_count = message_as_json["files_count"]
      
      if !is_bulk_update && encompass_loan_guid.blank?
        stage_id = message_as_json["stage_id"]
        stage_id = stage_id.to_s
        
        if stage_ids.include?(stage_id)  
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
                response = assign_loan_associate_milestone(access_token, loan_guid, "82a8bd4c-c449-4bdc-8c14-7845c869e045", {
                  id: "sgarcia",
                  roleName: "Loan Officer",
                  loanAssociateType: "User"
                }, false)

                if !response.nil?
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
                    loan_number, loan_purpose, loan_type, interest_rate, current_address, 
                      subject_property_address, employer_name, employer_address, borrowers_total_income, 
                        appraisal_value, birthday, closing_date, ltv, current_loan_balance, piti = nil 
                    
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
                    
                    url = "https://api.pipedrive.com/v1/deals/#{deal_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
                    uri = URI.parse(url)
                    request = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
                    body = {
                      '8804ec59511693ea1a2789605ebb60634367a164': (loan_guid.nil? ? "" : loan_guid),
                      '39ef775c13d95d43807a1185aa9068a49748646d': (loan_number.nil? ? "" : loan_number),
                      'c4612b19a74ccaa46af6deb7692d83f53bb56a5c': (loan_purpose.nil? ? "" : loan_purpose),
                      'd27f00dd19b57f6edfffed557cf76592aeda93da': (loan_type.nil? ? "" : loan_type),
                      '88135c0b31f5236ac50afb55dc00f3fd6cf6cff5': (interest_rate.nil? ? "" : interest_rate),
                      'f34a68618c73a6336f5c27056b7229bfde08b330': (current_address.nil? ? "" : current_address),
                      '3f4f6458517519d0a98974a4c626bc8264807cec': (subject_property_address.nil? ? "" : subject_property_address),
                      'a4d5d105dda89732508c86905804dc93cd48dbd1': (employer_name.nil? ? "" : employer_name),
                      '4bcd94d9c13feb7a3f2818abaf3a3b77108039fc': (employer_address.nil? ? "" : employer_address),
                      'f4a94170b859ba6cf8ed8eb86745004809eb2cd6': (borrowers_total_income.nil? ? "" : borrowers_total_income),
                      'd7328b1d41abe2be39b7ecc351f2ce61a2fd71a1': (appraisal_value.nil? ? "" : appraisal_value),
                      'bc1276296f056f035541dc45a1de1ade78786fc0': (current_loan_balance.nil? ? "" : current_loan_balance),
                      '3b7f6087cce987adb91868a2415427ff8786c40d': (birthday.nil? ? "" : birthday),
                      'bffb23c1a52bd7b398aad7589f767450b74f4ff2': (closing_date.nil? ? "" : closing_date),
                      'bd0cfc7013f35386da8c2c7d5fbe78c049a1881d': (piti.nil? ? "" : piti),
                      '7494f8dbd3435031ab6925c296912c20573617f4': (ltv.nil? ? "" : ltv),
                      'b0a83287d1683edaabc0294dd671f76b185ff1eb': name_lastname + " " + phone
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

                      if files_count > 0
                        p "UPLOADING FILES FROM PIPEDRIVE TO ENCOMPASS"

                        upload_files_pipedrive_encompass(deal_id, encompass_loan_guid)
                      end
                    else
                      p "ERROR UPDATING DEAL ON PIPEDRIVE"
                      p response
                      p response.body
                    end
                  else
                    p "ERROR OBTAINING LOAN INFORMATION"
                  end
                else
                  p "ERROR ASSOCIATING LOAN TO MILESTONE"
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
        # UPDATING CP FIELD
        update_cp_field(deal_id, person_id, name_lastname)
        update_campaign_name(deal_id)
      elsif !is_bulk_update
        stage_id = message_as_json["stage_id"]
        stage_id = stage_id.to_s
        
        if stage_ids.include?(stage_id)
          if files_count > 0
            upload_files_pipedrive_encompass(deal_id, encompass_loan_guid)
          end
        end
        update_cp_field(deal_id, person_id, name_lastname)
        update_campaign_name(deal_id)
      end
    end
  end

  private
  def update_campaign_name(deal_id)
    url = "https://api.pipedrive.com/v1/deals/#{deal_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
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
      nombre_campana_radio_listado = data["80ceec8086891a06d28c49a6aa350813b7f3518b"]
      org_id = data["org_id"]

      sw = false
      if org_id.nil?
        sw = true
      elsif
        if org_id["name"] != "Facebook Leads"
          sw = true
        end
      end
      
      if sw
        if nombre_campana_radio_listado == "16"
          nombre_campana_radio_listado = "Jorge - Sábado" 
        elsif nombre_campana_radio_listado == "17"
          nombre_campana_radio_listado = "Carmen - Sábado"
        elsif nombre_campana_radio_listado == "18"
          nombre_campana_radio_listado = "Jorge - Días Semana"
        elsif nombre_campana_radio_listado == "19"
          nombre_campana_radio_listado = "Jorge Messenger"
        elsif nombre_campana_radio_listado == "20"
          nombre_campana_radio_listado = "Jorge - Listado"
        elsif nombre_campana_radio_listado == "21"
          nombre_campana_radio_listado = "Carmen - Listado"
        end

        url = "https://api.pipedrive.com/v1/deals/#{deal_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
        uri = URI.parse(url)
        request = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
        body = {
          'fbf14eaf432d7b6ab2a6fa8cac8b6c2ad24d6865': nombre_campana_radio_listado
        }
        request.body = JSON.dump(body)

        req_options = {
          use_ssl: uri.scheme == "https",
        }
        
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
        
        if response.is_a?(Net::HTTPSuccess)
          p "UPDATED CAMPAIGN NAME, OK"
        else
          p "UPDATED CAMPAIGN NAME, ERROR"
        end
      end
    end    
  end

  def update_cp_field(deal_id, person_id, name_lastname)
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
            
      phone = phones.size > 0 ? phones[0]["value"] : ""
      
      url = "https://api.pipedrive.com/v1/deals/#{deal_id}?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
      uri = URI.parse(url)
      request = Net::HTTP::Put.new(uri, 'Content-Type' => 'application/json')
      body = {
        'b0a83287d1683edaabc0294dd671f76b185ff1eb': name_lastname + " " + phone
      }
      request.body = JSON.dump(body)

      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      
      if response.is_a?(Net::HTTPSuccess)
        p "CP VARIABLE UPDATED"
      else
        p "ERROR UPDATING CP VARIABLE"
        p response
        p response.body
      end
    else
      p "ERROR OBTAINING PERSON INFORMATION FROM PIPEDRIVE"  
    end
  end

  def upload_files_pipedrive_encompass(deal_id, encompass_loan_guid)
    sw = true
    start = 0
    access_token = nil

    while sw
      url = "https://api.pipedrive.com/v1/deals/#{deal_id}/files?start=#{start}&api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri)
      
      req_options = {
        use_ssl: uri.scheme == "https"
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      
      if response.is_a?(Net::HTTPSuccess)
        answer = JSON.parse(response.body)
        data = answer["data"]
        additional_data = answer["additional_data"]
        
        data.each do |item|
          file_id = item["id"]
          file_name = item["remote_id"]
          url_to_download_file = item["url"]

          items = FileQueue.where(file_id: item["id"])

          if items.count == 0
            # The file must be uploaded to Encompass
            if access_token.nil?
              access_token = admin_access_token
            end
            
            if !loan_is_open(access_token, encompass_loan_guid)
              begin
                file = open(url_to_download_file+"?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}")
                file = file.read
                upload_document_to_encompass(access_token, encompass_loan_guid, file_name, file)
                # fq = FileQueue.new(deal_id: deal_id, file_id: file_id, file_name: file_name, loan_guid: encompass_loan_guid, saved_encompass: true, url_to_download_file: url_to_download_file)
                # fq.save
              rescue => e
                p "CRASHED OPENING APP, QUEQUING FILE TO BE UPLOADED TO ENCOMPASS, LOAN GUID: #{encompass_loan_guid}, FILE ID: #{file_id}"
                if FileQueue.where(loan_guid: encompass_loan_guid).where(url_to_download_file: url_to_download_file).where(saved_encompass: false).count == 0
                  fq = FileQueue.new(deal_id: deal_id, file_id: file_id, file_name: file_name, loan_guid: encompass_loan_guid, url_to_download_file: url_to_download_file)
                  fq.save
                end
              end
            else
              p "LOAN IS OPEN, QUEQUING FILE TO BE UPLOADED TO ENCOMPASS, LOAN GUID: #{encompass_loan_guid}, FILE ID: #{file_id}"
              if FileQueue.where(loan_guid: encompass_loan_guid).where(url_to_download_file: url_to_download_file).where(saved_encompass: false).count == 0
                fq = FileQueue.new(deal_id: deal_id, file_id: file_id, file_name: file_name, loan_guid: encompass_loan_guid, url_to_download_file: url_to_download_file)
                fq.save
              end
            end                      
          end
        end
        
        pagination = additional_data["pagination"]
        more_items_in_collection = pagination["more_items_in_collection"]
        if more_items_in_collection
          start_temp = pagination["start"]
          limit = pagination["limit"]
          next_temp = start_temp + limit + 1
          start = next_temp.to_s
        end
        sw = more_items_in_collection
      else
        p "ERROR REQUESTING FILES FROM A DEAL FROM PIPEDRIVE"
        sw = false
      end
    end    
  end
end