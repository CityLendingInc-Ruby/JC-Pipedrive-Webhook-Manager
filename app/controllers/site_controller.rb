class SiteController < ApplicationController
  def index
    render json: Rabl::Renderer.json(nil, 'site/index'), status: :ok
  end
end