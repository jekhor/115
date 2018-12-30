#!/usr/bin/ruby
# encoding: utf-8

require 'json'

if ARGV.empty?
  STDERR.puts "Usage: #{__FILE__} <data.geojson> > <output.txt>"
  exit 1
end

json = JSON.parse(File.read(ARGV[0]))

users = {}

json['features'].each do |problem|
  user = problem['properties']['user']
  if user.nil?
    STDERR.puts "Empty user for problem #{problem.inspect}"
    next
  end
  users[user['id']] = user if users[user['id']].nil?
  users[user['id']]['problems'] = [] if users[user['id']]['problems'].nil?
  users[user['id']]['problems'] << problem['properties']['id']
end

puts "User id,Last Name,Name,Middle Name,Problems count,problems"
sorted = users.values.sort_by { |a| -a['problems'].size }
lines = sorted.map {|u| "#{u['id']},#{u['last_name']},#{u['name']},#{u['middle_name']},#{u['problems'].size},#{u['problems'].join(',')}"}
puts lines.join("\n")

