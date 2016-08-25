#ActiveOrient::Model.orientdb_class name: 'time_base', superclass: 'V'
class Monat  < TimeBase
  def der_tag d
#    d=d-1
    d >0 && d<31 ? out_day_of[d].in : nil
  end
 
  # returns an array of days
  # thus enables the use as  
  #   Monat[9].tag[9]
  def tag
    out_day_of.in
  end

  # returns the specified edge 
  #  i.e.  Monat[9]
  #

end
