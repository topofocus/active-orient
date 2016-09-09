#ActiveOrient::Model.orientdb_class name: 'time_base', superclass: 'V'
class  TG::Tag  < TG::TimeBase
def monat
  in_day_of.out.value_string.first
end

def die_stunde h
    h.to_i >0 && h.to_i<31 ? out_time_of[h].in : nil
  end
  
  def stunde *key
    if key.empty?
    out_time_of.in
    else
    query( "select  expand (out_time_of.in[#{db.generate_sql_list 'value' => key.analyse}]) from #{rrid}  ")
    end
  end


  def monat
    in_day_of.out.first
  end
  def next
    monat.tag[ value + 1 ]
  end
  def prev
    monat.tag[ value - 1 ]
  end

  def datum
    m = monat
    "#{ value}.#{m.value}.#{m.jahr.value}"
  end
end
