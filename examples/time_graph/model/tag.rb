#ActiveOrient::Model.orientdb_class name: 'time_base', superclass: 'V'
class  Tag  < TimeBase
def monat
  in_day_of.out.value_string.first
end

def die_stunde h
    h.to_i >0 && h.to_i<31 ? out_time_of[h].in : nil
  end
  
def self.[] key
  stunde key
end
  def stunde
    out_time_of.in
  end
  def next
    puts value.inspect
    in_day_of.out.first.tag( value + 1 )
  end

  def datum

  end
end
