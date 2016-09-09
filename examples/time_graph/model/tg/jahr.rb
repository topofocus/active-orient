
class TG::Jahr  < TG::TimeBase
  def der_monat m
    d >0 && m<13 ? out_month_of[m].in : nil
  end
 
  # returns an array of days
  # thus enables the use as  
  #   Monat[9].tag[9]
  def monat  *key

    if key.empty?
    out_month_of[key].in
    else
    query( "select  expand (out_month_of.in[#{db.generate_sql_list 'value' => key.analyse}]) from #{rrid}  ")
    end
  end

  end

