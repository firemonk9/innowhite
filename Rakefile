require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('innowhite', '0.1.0') do |p|
  p.description    = "Innowhite Api"
  p.url            = "http://github.com/firemonk9/innowhite"
  p.author         = "firemonk"
  p.email          = "dhiraj.peechara@gmail.com"
  p.ignore_pattern = ["tmp/*", "script/*"]
  p.development_dependencies = []
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }
