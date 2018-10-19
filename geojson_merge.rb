#!/usr/bin/ruby
# encoding: utf-8

require 'json'


result = {
  type: 'FeatureCollection',
  features: []
}

ARGV.each do |file|
  result[:features] += JSON.parse(File.read(file))['features']
end

puts JSON.pretty_generate(result)

