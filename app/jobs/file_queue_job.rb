class FileQueueJob < ApplicationJob
  class_timeout 600

  rate "10 minutes"
  def process
    access_token = nil
    FileQueue.where(saved_encompass: false).all.each do |fq|
      p "==============="
      p fq
      p "==============="
      begin
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
            file = open(url_to_download_file+"?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}")
            size = File.size(url_to_download_file+"?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}")
            p "Size:"
            p size
            contentType = MiniMime..lookup_by_filename(url_to_download_file+"?api_token=#{ENV['PIPEDRIVE_API_TOKEN']}").content_type
            p "contentType:"
            p contentType 
            file = file.read
            #answer = upload_document_to_encompass(access_token, loan_guid, file_name, contentType, size, file)
            if answer.size > 0
              answer = answer[0]
              #fq.update_attributes(comment: answer["message"], saved_encompass: true)
            else
              #fq.update_attributes(comment: "ERROR UPLOADING FILE TO ENCOMPASS")
            end
          else
            #fq.update_attributes(comment: "LOAN IS OPEN")
          end
        else
          #fq.update_attributes(comment: "ERROR UPLOADING DOCUMENTS: MAIN USER / PASSWORD")
        end
      rescue => e
        p "--------------- ERROR -----------------"
        p e.class
        #fq.update_attributes(comment: "APP CRASHED")
      end
    end
    token_revocation(access_token) unless access_token.nil?
  end
end