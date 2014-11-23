#!/usr/bin/env ruby

require 'date'
require 'JSON'
require 'faraday'
require 'sequel'

project_id = ENV['TRACKER_PROJECT_ID']
token = ENV['TRACKER_TOKEN']

connection = Faraday.new(url: 'https://www.pivotaltracker.com')

limit = 1000
offset = 0
activities = []
received_data = true
while received_data
  response = connection.get("/services/v5/projects/#{project_id}/activity", limit: limit, offset: offset) do
    |req| req.headers['X-TrackerToken'] = token
  end
  as = JSON.parse response.body
  activities.concat as
  received_data = !as.empty?
  offset += 400
end

activities.uniq!

DB = Sequel.sqlite('db/tracker_events.db')

DB.create_table :events do
  primary_key :id
  String :kind
  DateTime :occurred_at
  Integer :project_id
  Integer :story_id
  String :from_state
  String :to_state
  String :raw_json, text: true
end

events = DB[:events]

activities.each do |a|
  story_changes = a['changes'].select { |c| c['kind'] == 'story' }
  story_changes.each do |change|
    events.insert(
      kind: a['kind'],
      occurred_at: DateTime.parse(a['occurred_at']),
      project_id: a['project']['id'],
      story_id: change['id'],
      from_state: (change['original_values'] || {})['current_state'],
      to_state: (change['new_values'] || {})['current_state'],
      raw_json: a.to_json
    )
  end
end
