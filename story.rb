require 'sequel'

class Story
  COLUMNS = %i(kind occurred_at project_id project_version story_id from_state to_state)

  STATES = %w(unscheduled unstarted started finished delivered rejected accepted)
  # NOTE: WORKING_STATES_RANGE excludes rejected
  WORKING_STATES_RANGE = STATES.index('started')..STATES.index('finished')

  attr_reader :working_durations

  def self.table
    @_table ||= Sequel.sqlite('db/tracker_events.db')[:events]
  end

  def self.all
    table.db['SELECT DISTINCT(story_id) FROM events'].all.map do |i|
      new i[:story_id]
    end
  end

  def initialize id
    @id = id
    @working_durations = []
    process_events
  end

  def days_worked
    working_durations.reduce(0) do |acc, duration|
      acc + (duration.end.to_date - duration.begin.to_date).round
    end
  end

  private

  def process_events
    working_duration_start = nil
    events.each do |e|
      if working_state? e[:to_state]
        working_duration_start ||= e[:occurred_at]
      elsif working_duration_start
        @working_durations << (working_duration_start..e[:occurred_at])
        working_duration_start = nil
      end
    end
  end

  def events
    table.
      select(*COLUMNS).
      where(story_id: @id).
      where('from_state IS NOT NULL OR to_state IS NOT NULL').
      order(:occurred_at, :project_version).
      all
  end

  def table
    self.class.table
  end

  def working_state? state
    WORKING_STATES_RANGE.include? STATES.index(state)
  end
end
