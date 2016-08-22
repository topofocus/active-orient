class Stunde < TimeBase

  def tag
    in_time_of.out
  end

  def datum
    month = in_time_of.out.in_day_of.out.value
    day =  in_time_of.out.value
    puts "Day: #{day.inspect}"
    puts "Month: #{month.inspect}"
  end
  def next
    puts value.inspect
    in_day_of.out.first.tag( value + 1 )
  end
end
