class WebhookController < ApplicationController
  def index
    p params
    render json: "OK", status: :ok
  end
end