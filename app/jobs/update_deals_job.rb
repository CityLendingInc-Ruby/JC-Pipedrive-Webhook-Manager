class UpdateDealsJob < ApplicationJob
  class_timeout 600
  
  rate "1 hour"
  def process
    stage_ids = ["3","8","10"]
    start = 0
    access_token = nil
    
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

    stage_ids.each do |stage_id|
      sw = true
      while sw do
        url = "https://api.pipedrive.com/v1/stages/#{stage_id}/deals?everyone=1&start=#{start}&api_token=#{ENV['PIPEDRIVE_API_TOKEN']}"
        
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
          additional_data = answer["additional_data"]

          data.each do |item|
            deal_id = item["id"]

            loan_guid = item["8804ec59511693ea1a2789605ebb60634367a164"]

            if !loan_guid.blank?
              if access_token.nil?
                access_token = admin_access_token
              end

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
                  '7494f8dbd3435031ab6925c296912c20573617f4': (ltv.nil? ? "" : ltv)
                }
                request.body = JSON.dump(body)

                req_options = {
                  use_ssl: uri.scheme == "https",
                }
                
                response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
                  http.request(request)
                end
                
                if response.is_a?(Net::HTTPSuccess)
                  p "DEAL: #{deal_id}, UPDATED ON PIPEDRIVE"
                else
                  p "ERROR UPDATING DEAL: #{deal_id} ON PIPEDRIVE"
                  p response
                  p response.body
                end
              else
                p "ERROR OBTAINING LOAN INFORMATION, DEAL: #{deal_id}, LOANGUID: #{loan_guid}"
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
          p "ERROR GETTING DEALS FROM PIPEDRIVE"
          sw = false
        end
      end
    end
    token_revocation(access_token) unless access_token.nil?
  end
end