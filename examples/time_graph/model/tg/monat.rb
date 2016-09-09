class TG::Monat  < TG::TimeBase
  def der_tag d
#    d=d-1
    d >0 && d<31 ? out_day_of[d].in : nil
  end
 
  # returns an array of days
  # thus enables the use as  
  #   Monat[9].tag[9]
  def tag *key
    if key.empty?
    out_day_of.in
    else
    query( "select  expand (out_day_of.in[#{db.generate_sql_list 'value' => key.analyse}]) from #{rrid}  ")
    end
  end

  # returns the specified edge 
  #  i.e.  Monat[9]
  #
  
  def jahr
    in_month_of.out.first
  end
end
