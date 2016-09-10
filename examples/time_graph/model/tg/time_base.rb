class  TG::TimeBase < V

=begin
Searches for specific value records 

Examples
  Monat[8]  --> Array of all August-month-records
  Jahr[1930 .. 1945]
=end
  def self.[] *key
    result = OrientSupport::Array.new( work_on: self, work_with: db.execute{ "select from #{ref_name} #{db.compose_where( value: key.analyse)}" } )
    result.size == 1 ? result.first : result # return object if only one record is fetched
  end


  def analyse_key key

    new_key=  if key.first.is_a?(Range) 
			   key.first
			elsif key.size ==1
			 key.first
			else
			  key
			end
  end

  def environment previous_items = 10, next_items = nil
    next_items =  previous_items  if next_items.nil?  # default : symmetric fetching

    my_query =  -> (count) { dir =  count <0 ? 'in' : 'out';   db.execute {  "select from ( traverse #{dir}(\"grid_of\") from #{rrid} while $depth <= #{count.abs}) where $depth >=1 " } }  # don't fetch self
    
   prev_result = previous_items.zero? ?  []  :  my_query[ -previous_items ] 
   next_result = next_items.zero? ?  []  : my_query[ next_items ] 

    prev_result.reverse  << self | next_result 
  end
end
