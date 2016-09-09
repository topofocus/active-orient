class TG::Stunde < TG::TimeBase

  def tag
    in_time_of.out
  end

  def datum
    month = in_time_of.out.in_day_of.out.value
    day =  in_time_of.out.value
    "#{day.first}.#{month.flatten.first}.#{Date.today.year} #{value}:00"
  end
  def next
    puts value.inspect
    in_day_of.out.first.tag( value + 1 )
  end
end
