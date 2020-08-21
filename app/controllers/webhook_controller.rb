class WebhookController < ApplicationController
  def index
    jets meta = params["meta"]
    deal_id = meta["id"]
    is_bulk_update = meta["is_bulk_update"]

    current = params["current"]
    stage_id = current["stage_id"]
    name_lastname = current["title"]
    person_id = current["person_id"]
    
    sns = Aws::SNS::Resource.new(region: ENV["REGION"])
    topic = sns.topic('arn:aws:sns:us-east-1:443216489626:jc-pipedrive-webhook-manager-job-processing')

    topic.publish({
      deal_id: deal_id,
      is_bulk_update: is_bulk_update,
      stage_id: stage_id,
      name_lastname: name_lastname,
      person_id: person_id
    })

    render json: "OK", status: :ok
  end
end