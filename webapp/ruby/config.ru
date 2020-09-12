lib = File.expand_path('../lib', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

require 'concurrent-ruby'
require 'recurl'
require 'isucari/web'

if ENV['lp'] == '1'
  puts 'Enabled lineprof'
  require 'rack-lineprof'
  use Rack::Lineprof, profile: 'isucari/web.rb'
end

if ENV['sp'] == '1'
  puts 'Enabled stackprof'
  require 'stackprof'
  system 'rm -rf ./tmp'
  use StackProf::Middleware, enabled: true, mode: :cpu, interval: 10_000, raw: true
end

if ENV['curl'] == '1'
  puts 'Enabled recurl'
  use Recurl::Rack::Middleware
end


run Isucari::Web
