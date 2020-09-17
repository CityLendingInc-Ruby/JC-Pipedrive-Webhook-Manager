class FileQueueJob < ApplicationJob
  rate "10 hours" # every 10 hours
  def process
    FileQueue.where(saved_encompass: false).all.each do |fq|
      deal_id = fq.deal_id
      file_id = fq.file_id
      file_name = fq.file_name
      loan_guid = fq.loan_guid
      url_to_download_file = fq.url_to_download_file
      
      access_token = admin_access_token
      messages = []
      
      if !access_token.nil?
        filter = {
          loanGuids: [
            "#{loan_guid}"
          ],
          fields: [
            "Fields.GUID",
            "Fields.4000",
            "Fields.4002",
            "Fields.LoanTeamMember.Email.Loan Processor",
            "Fields.LoanTeamMember.Email.Loan Officer",
            "Fields.LoanTeamMember.Email.Branch Manager",
            "Fields.LoanTeamMember.Email.LO Assistant",
            "Fields.CX.UWCONDTYPE",
            "Fields.CX.BSPCRCOMMENT"
          ]
        }
  
        loans = loans_by_filter(access_token, filter)
        if !loans.nil? and !loans.first.nil?
          loan = loans.first
  
          loan_processor_email = loan["fields"]["Fields.LoanTeamMember.Email.Loan Processor"]
          loan_officer_email = loan["fields"]["Fields.LoanTeamMember.Email.Loan Officer"]
          branch_manager_email = loan["fields"]["Fields.LoanTeamMember.Email.Branch Manager"]
          lo_assistant_email = loan["fields"]["Fields.LoanTeamMember.Email.LO Assistant"]
          uw_condition_type = loan["fields"]["Fields.CX.UWCONDTYPE"]
          comment = loan["fields"]["Fields.CX.BSPCRCOMMENT"]
          comment = comment.force_encoding('UTF-8')
          pre_uw_condition_type = ""

          if uw_condition_type == "UW Cond"
            pre_uw_condition_type = "UC - "
          elsif uw_condition_type == "Proc Conditions"
            pre_uw_condition_type = "PC - "
          end

          borrower_name = "Borrower Name: #{loan["fields"]["Fields.4000"]} #{loan["fields"]["Fields.4002"]}"
          
          url = doc.file_url
          supported_formats = [".pdf", ".doc", ".docx", ".txt", ".tif", ".jpg", ".jpeg", ".jpe", ".emf", ".xps"]
          files_not_to_upload = ["image001.png", "image002.png", "image003.png", "image004.png", "image005.png", "image006.png", "image007.png", "image008.png"]

          if !loan_is_open(access_token, loan_guid)
            file = open_file(url)
            filename = file["content-disposition"].match(/filename=(\"?)(.+)\1/)[2]
            original_filename = filename
            filename = filename.downcase
            if filename.include?(".zip")
              Zip::File.open_buffer(file.body) do |zip_file|
                zip_file.each do |entry|
                  count = 0
                  original_filename = entry.name
                  filename = original_filename.downcase
                  if !files_not_to_upload.include?(filename)
                    supported_formats.each{|item| (count = count + 1) if filename.include?(item) }
                    if count > 0
                      messages += upload_document_to_encompass(access_token, loan_guid, pre_uw_condition_type + original_filename, entry.get_input_stream.read)
                    else
                      messages.push({status: "error", message: "#{pre_uw_condition_type + original_filename}: Not Supported Format"})
                    end
                  end
                end
              end
            else
              count = 0
              if !files_not_to_upload.include?(filename)
                supported_formats.each{|item| (count = count + 1) if filename.include?(item) }
                if count > 0
                  messages += upload_document_to_encompass(access_token, loan_guid, pre_uw_condition_type + original_filename, file.body)
                else
                  messages.push({status: "error", message: "#{pre_uw_condition_type + original_filename}: Not Supported Format"})
                end
              end
            end
            doc.update_attributes(saved_encompass: true, encompass_response: messages.map{|m| m[:message]}.join("\n") + "\n#{borrower_name}")

            now = Time.now.in_time_zone("America/New_York")
            date = now.strftime("%m/%d/%Y")
            time = now.strftime("%I:%M %p")
            uw_condition_type = uw_condition_type.nil? ? "" : uw_condition_type
            comment = comment.nil? ? "" : comment
            username = username.nil? ? "" : username
            new_comment = "*** #{date} #{time} *** #{uw_condition_type} - #{from_email_address_username}\n#{email_body}\n"
            comment = new_comment + comment

            statuses_ok_counter = messages.map{|m| m[:status]}.count{|item| item == "ok"}
            messages_formatted = "Timestamp: #{date} #{time}\n"
            messages_formatted = messages_formatted + messages.map{|m| m[:message]}.join("\n") + "\n#{borrower_name}"
            
            if statuses_ok_counter > 0 and !access_token.nil?
              body = {
                customFields:[
                  {
                    id: 'CX.UWDATELAST',
                    stringValue: date
                  },
                  {
                    id: 'CX.UWTIMELAST',
                    stringValue: time
                  },
                  {
                    id: 'CX.UWCONDFLAG',
                    stringValue:'Y'
                  },
                  {    
                    id: 'CX.PROJECT',
                    stringValue: "Upload Docs"
                  },
                  {
                    id: 'CX.BSPCRCOMMENT',
                    stringValue: "#{comment}"
                  },
                  {
                    id: 'CX.CONDUSER',
                    stringValue: "#{from_email_address_username}"
                  }
                ]
              }
              message = nil
              if !update_loan(access_token, loan_guid, body).nil?
                p message = "OK Updating Fields into Encompass"
              else
                p message = "ERROR Updating Fields into Encompass"
              end
            end
            
            message_lo_and_loa = "Thank you for submitting your conditions #{date} #{time}. They are now available on file manager and your processor will review them shortly. #{loan_processor_email}\n#{borrower_name}"
            
            if !loan_officer_email.blank? and !lo_assistant_email.blank?
              UploadDocumentsMailer.upload_documents_cc(loan_officer_email, lo_assistant_email, message_lo_and_loa, loan_number).deliver
            elsif !loan_officer_email.blank? or !lo_assistant_email.blank?
              to = loan_officer_email.blank? ? lo_assistant_email : loan_officer_email
              UploadDocumentsMailer.upload_documents(to, message_lo_and_loa, loan_number).deliver
            end
            
            if !loan_processor_email.blank?
              UploadDocumentsMailer.upload_documents(loan_processor_email, "You received conditions on this file: #{loan_number}", loan_number).deliver
            end
            
            if !branch_manager_email.blank?
              UploadDocumentsMailer.upload_documents_cc(from_email_address, branch_manager_email, messages_formatted, loan_number).deliver
            else
              UploadDocumentsMailer.upload_documents(from_email_address, messages_formatted, loan_number).deliver
            end
          else
            doc.update_attributes(saved_encompass: false, encompass_response: "")
          end
        else
          messages.push({message: "LOAN NUMBER IS NOT VALID", status: "error"})
        end
      else
        messages.push({message: "ERROR UPLOADING DOCUMENTS: MAIN USER / PASSWORD", status: "error"})
      end
      
      token_revocation(access_token) unless access_token.nil?
    end
  end
end