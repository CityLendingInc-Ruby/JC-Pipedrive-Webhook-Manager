require 'rabl'
Rabl.configure do |config|
  config.view_paths = [Jets.root.join('app', 'views')]
end