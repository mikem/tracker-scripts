#!/usr/bin/env ruby

require 'tracker_api'
require 'terminal-table'

project_id = ENV['TRACKER_PROJECT_ID']
token = ENV['TRACKER_TOKEN']

velocity_weeks = 4

client = TrackerApi::Client.new token: token
project = client.project project_id
iterations = project.iterations

last_iteration_index = iterations.length - 1
while iterations[last_iteration_index].finish.to_date > Date.today
  last_iteration_index -= 1
end

first_iteration_index = [last_iteration_index - 20, 1].max

data = iterations[first_iteration_index..last_iteration_index].map do |i|
  {
    iteration_number: i.number,
    start: i.start,
    finish: i.finish,
    story_count: i.stories.length,
    points_total: 0,
    feature_count: 0,
    bug_count: 0,
    chore_count: 0,
    release_count: 0
  }.tap do |h|
    i.stories.each do |s|
      h[:points_total] += s.estimate.to_i
      h["#{s.story_type}_count".to_sym] += 1
    end
  end
end

headings = %w(Iteration Start Finish Points Stories Features Bugs Chores Releases)
rows = data.map do |d|
  [
    d[:iteration_number],
    d[:start].strftime('%b %e'),
    d[:finish].strftime('%b %e'),
    d[:points_total],
    d[:story_count],
    d[:feature_count],
    d[:bug_count],
    d[:chore_count],
    d[:release_count]
  ]
end

puts Terminal::Table.new headings: headings, rows: rows

summary_first_iteration_index = [last_iteration_index - 3, 1].max
summary = {
  velocity: [],
  story_count: [],
  points_total: [],
  feature_count: [],
  bug_count: [],
  chore_count: []
}.tap do |h|
  iterations[summary_first_iteration_index..last_iteration_index].map do |i|
    h[:velocity] << nil
    points_total = 0
    feature_count = 0
    bug_count = 0
    chore_count = 0
    i.stories.each do |s|
      points_total += s.estimate.to_i
      case s.story_type
      when 'feature'
        feature_count += 1
      when 'bug'
        bug_count += 1
      when 'chore'
        chore_count += 1
      end
    end
    h[:points_total] << points_total
    h[:feature_count] << feature_count
    h[:bug_count] << bug_count
    h[:chore_count] << chore_count
    h[:story_count] << i.stories.length
  end
  h[:velocity] = h[:points_total].reverse.first(velocity_weeks).reduce(0, :+) / velocity_weeks
end

summary_rows = [['Velocity', { value: "#{summary[:velocity]} (#{velocity_weeks} week avg)", colspan: 4 }]]
summary_rows << ['Points'] + summary[:points_total].reverse
summary_rows << ['Total Stories'] + summary[:story_count].reverse
summary_rows << ['Feature count'] + summary[:feature_count].reverse
summary_rows << ['Bug count'] + summary[:bug_count].reverse
summary_rows << ['Chore count'] + summary[:chore_count].reverse
puts Terminal::Table.new rows: summary_rows
