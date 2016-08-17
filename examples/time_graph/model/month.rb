class Monat # < TimeBase
  def tag d
    d=d-1
    d >0 && d<31 ? out_day_of[d].in : nil
  end
  
  def tage
    out_day_of.in
  end


end
