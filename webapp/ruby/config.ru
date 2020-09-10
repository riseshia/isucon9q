lib = File.expand_path('../lib', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

require 'newrelic_rpm'

require 'isucari/web'

run Isucari::Web
