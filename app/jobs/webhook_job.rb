class WebhookJob < ApplicationJob
  class_timeout 90

  sns_event "jc-pipedrive-webhook-manager-job-processing"
  def process
    p "----------------------------- PRUEBA SNS --------------------"
    p event
    p "-------------------------------------------------------------"
  end
end