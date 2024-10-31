# app/services/schedule_processor.rb
# This Class will handle the core business logic of our Scheduler
class ScheduleProcessor
  @final_schedule = [ Array.new(24, false), Array.new(24, false), Array.new(24, false), Array.new(24, false), Array.new(24, false), Array.new(24, false),
                     Array.new(24, false) ]
  Show = Struct.new(:show_name, :rj_name)

  def self.process
    puts "Handling the core scheduler business logic here."
    self.process_returning_rj_retaining_their_slots
    self.sort_and_assign_timeslots_for_remaining_rjs
  end

  def self.get_schedule
    @final_schedule
  end

  def self.is_available(day, hour)
    @final_schedule[day][hour] == false
  end

  def self.is_available_db(day, hour)
    entry = ScheduleEntry.find_by(day: day, hour: hour)
    entry.empty?
  end

  def self.add_entry(day, hour, jockey)
    entry = ScheduleEntry.find_by(day: day, hour: hour)

    # Update the entry with new values if it exists
    if entry
      entry.update(
        show_name: jockey.show_name,
        last_name: jockey.last_name,
        jockey_id: jockey.id
      )
    end
  end


  # Step 1
  def self.process_returning_rj_retaining_their_slots
    returning_rjs = RadioJockey.where(member_type: "Returning DJ", retaining: "yes").order(
      semesters_in_KANM: :desc, expected_grad: :asc, timestamp: :asc
    )

    returning_rjs.each do |jockey|
      # Apply the condition - update only if conditions are met (This condition must be set)
      # Find the existing ScheduleEntry for the given day and hour
      add_entry(jockey.best_day, jockey.best_hour, jockey)
    end
    puts "Processing returning RJ who've retaining their slots."
  end

  def self.best_alt_time_ranges(best_time, range, alt_times)
    min_time = best_time - range
    max_time = best_time + range
    check_yesterday = false
    check_tomorrow = false
    adj_day_range = 0

    if best_time < range
      check_yesterday = true
      adj_day_range = 0 - min_time
      min_time = 0
    elsif best_time > (23 - range)
      check_tomorrow = true
      adj_day_range = max_time - 23
      max_time = 23
    end
    range_values = {}
    alt_times.each do |key, values|
        in_range = values.select { |value| value.to_i >= min_time && value.to_i <= max_time }
        range_values[key] = in_range unless in_range.empty?
    end
    range_values
  end

  def self.assemble_alt_times(rj)
    times = {}
    times[:Monday] = RadioJockey.process_alt_times(rj.alt_mon)
    times[:Tuesday] = RadioJockey.process_alt_times(rj.alt_tue)
    times[:Wednesday] = RadioJockey.process_alt_times(rj.alt_wed)
    times[:Thursday] = RadioJockey.process_alt_times(rj.alt_thu)
    times[:Friday] = RadioJockey.process_alt_times(rj.alt_fri)
    times[:Saturday] = RadioJockey.process_alt_times(rj.alt_sat)
    times[:Sunday] = RadioJockey.process_alt_times(rj.alt_sun)

    times
  end

  def self.print_final_schedule
    schedule = ScheduleEntry.all
    schedule.each do |day|
      puts day.attributes
    end
  end

  def self.num_from_day(day)
    case day.downcase
    when "monday"
      0
    when "tuesday"
      1
    when "wednesday"
      2
    when "thursday"
      3
    when "friday"
      4
    when "saturday"
      5
    when "sunday"
      6
    else
      puts "Invalid day!"
    end
  end

  def self.generate_schedule(sorted_rjs)
    sorted_rjs.each do |rj|
      alt_times = assemble_alt_times(rj)
      if is_available(num_from_day(rj.best_day), rj.best_hour.to_i)
        @final_schedule[num_from_day(rj.best_day)][rj.best_hour.to_i] = Show.new(rj.show_name, rj.DJ_name)
        add_entry(rj.best_day, rj.best_hour, rj)
      else
        i = 3
        while i <= 12
          best_avail = best_alt_time_ranges(rj.best_hour.to_i, i, alt_times)
          if best_avail[num_from_day(rj.best_day)] != nil
            num_times = best_avail[num_from_day(rj.best_day)].length
            good_hour = best_avail[num_from_day(rj.best_day)][num_times / 2]
            if is_available(num_from_day(rj.best_day), good_hour)
                @final_schedule[num_from_day(rj.best_day)][good_hour] = Show.new(rj.show_name, rj.DJ_name)
                add_entry(rj.best_day, good_hour, rj)
                break
            end
          else
            best_avail.each do |day, times|
              # puts best_avail
              # puts day
              # puts "---"
              # puts times
              if not day.empty?
                day_as_num = num_from_day(day.to_s)
                num_times = times.length
                good_hour = times[num_times / 2]
                # puts "good hour"
                # puts good_hour
                if is_available(day_as_num, good_hour.to_i)
                  @final_schedule[day_as_num][good_hour.to_i] = Show.new(rj.show_name, rj.DJ_name)
                  add_entry(day, good_hour, rj)
                  break
                end
              end
            end
          end
          i += 3
        end
      end
    end
    puts @final_schedule
  end

  # Step 2 and 3
  def self.sort_and_assign_timeslots_for_remaining_rjs
    puts "Processing all RJs who need to be assigned a new slot."

    # Read and Sort the RJs (Step 2)
    returning_rjs = RadioJockey.where(member_type: "Returning DJ", retaining: "no").order(
      semesters_in_KANM: :desc, expected_grad: :asc, timestamp: :asc
    )
    new_rjs = RadioJockey.where(member_type: "New DJ").order(
      semesters_in_KANM: :desc, expected_grad: :asc, timestamp: :asc
    )
    sorted_rjs = returning_rjs + new_rjs

    # (Step 3)
    # For each RJ, check first for their best slot being free in the schedule, populate if true, continue
    # If not, then get all the available slots, and find one which is free in the schedule, populate and continue
    # If this too failed, then add to the list of unassigned RJs, that we will display in the frontend
    generate_schedule(sorted_rjs)
    sorted_rjs.each do |rj|
      puts format(
        "UIN: %-11s\tDJ Name: %-15s Member Type: %-15s Semesters in KANM: %-5s Expected Graduation: %-8s Timestamp: %-20s",
        rj.UIN, rj.DJ_name, rj.member_type, rj.semesters_in_KANM, rj.expected_grad, rj.timestamp
      )
      print_final_schedule
      # Required code here
    end
  end
end
