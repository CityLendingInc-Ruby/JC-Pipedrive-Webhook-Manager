source "https://rubygems.org"

gem 'jets', '2.3.16'

gem 'dynamoid', '3.5.0'
gem 'rabl', '0.14.3'
gem 'oj', '3.10.6'

#gem 'rubyzip', '2.3.0'
#gem 'zip-zip', '0.3'
#gem 'nokogiri', '1.10.10'

# development and test groups are not bundled as part of the deployment
group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '11.0.1', platforms: [:mri, :mingw, :x64_mingw]
  gem 'shotgun', '0.9.2'
  gem 'rack', '2.2.3'
  gem 'puma', '4.2.1'
end

group :test do
  gem 'rspec', '3.9.0'
  gem 'launchy', '2.5.0'
  gem 'capybara', '3.32.2'
end