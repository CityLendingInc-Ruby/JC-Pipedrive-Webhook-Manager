Jets.application.routes.draw do
  root 'site#index'
  post '/webhook', to: 'webhook#index', as: 'webhook'
end