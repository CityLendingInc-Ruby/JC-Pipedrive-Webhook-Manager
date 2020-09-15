class FileQueue
  include Dynamoid::Document

  field :deal_id
  field :file_id
  field :file_name
  field :loan_guid
  field :saved_encompass, :boolean, default: false
end