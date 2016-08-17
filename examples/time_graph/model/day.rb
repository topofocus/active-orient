class  Tag # < TimeBase

def stunde h
    h >0 && h<31 ? out_time_of[h].in : nil
  end
  
  def stunden
    out_time_of.in
  end

end
