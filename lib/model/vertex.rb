class V   < ActiveOrient::Model
  ## link to the library-class
  # create 
  # seems not to be nessesary as its identically to the universal create

 
  # to do

  # def delete
  # delete an edge (as class method) 
  # and 
  # def remove
  # delete an edge (as instance method)
  
  def edges kind=:all  # :all, :in, :out 
    expression = case kind
		 when :all
		   /^in|^out/ 
		 when :in
		   /^in/ 
		 when :out
		   /^out/ 
    end
    edges = attributes.keys.find_all{ |x| x =~  expression }
    edges.map{|x| attributes[x]}.flatten
  end

  def remove
    db.delete_vertex self
  end

end
