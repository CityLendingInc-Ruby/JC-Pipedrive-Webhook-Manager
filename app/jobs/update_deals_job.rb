class UpdateDealsJob < ApplicationJob
  rate "10 hours" # every 10 hours
  def dig
    puts "done digging"
  end
end