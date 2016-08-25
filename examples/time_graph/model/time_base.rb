class  TimeBase < V

  def self.[] key
    where( value: key)
  end
end
