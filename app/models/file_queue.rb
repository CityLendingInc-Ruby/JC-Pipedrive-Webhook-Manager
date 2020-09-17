class FileQueue
  include Dynamoid::Document
  
  field :deal_id
  field :file_id
  field :file_name
  field :loan_guid
  field :comment
  field :saved_encompass, :boolean, default: false
  field :url_to_download_file
end