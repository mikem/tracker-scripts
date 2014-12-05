#!/usr/bin/env ruby

require 'tracker_api'
require 'terminal-table'

require_relative './story'

project_id = ENV['TRACKER_PROJECT_ID']
token = ENV['TRACKER_TOKEN']

client = TrackerApi::Client.new token: token
project = client.project project_id
iterations = project.iterations.reduce({}) do |acc, i|
  acc[i.number] = i.stories.map &:id
  acc
end

iteration_cycle_times = iterations.reduce({}) do |acc, iteration_story_ids|
  iteration_number = iteration_story_ids.first
  story_ids = iteration_story_ids.last
  acc[iteration_number] = story_ids.map { |id| { id => Story.new(id).days_worked } }
  acc
end

summary_rows = [['Iteration', 'Story ID', 'Days worked']]
iteration_cycle_times.each do |iteration, stories_and_days_worked|
  stories_and_days_worked.each do |story_and_days_worked|
    story_id = story_and_days_worked.keys.first
    days_worked = story_and_days_worked.values.first
    summary_rows << [iteration, story_id, days_worked]
  end
end

puts Terminal::Table.new rows: summary_rows
