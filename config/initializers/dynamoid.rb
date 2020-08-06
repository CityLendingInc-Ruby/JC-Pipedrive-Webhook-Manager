require 'dynamoid'

Dynamoid.configure do |config|
  if ENV['JETS_ENV'] == 'development'
    config.namespace = 'jc-pipedrive-webhook-manager-dev'
  elsif ENV['JETS_ENV'] == 'test'
    config.namespace = 'jc-pipedrive-webhook-manager-test'
    config.endpoint = 'http://localhost:8000'
  else
    config.namespace = 'jc-pipedrive-webhook-manager'
  end
  config.access_key = ENV['ACCESS_KEY_ID']
  config.secret_key = ENV['SECRET_ACCESS_KEY']
  config.region = ENV['REGION']
end

Dynamoid.included_models.each { |m| m.create_table(sync: true) }