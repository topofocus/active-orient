class  TimeBase < V

  def self.[] key
    where( value: key).first
  end
end
