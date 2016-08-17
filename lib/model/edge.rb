class E # < ActiveOrient::Model
=begin
establish contrains on Edges

Edges are uniq!

Creates individual indices for child-classes if applied to the class itself.
=end
  def  self.uniq_index
    create_property  :in,  type: :link, linked_class: :V
    create_property  :out, type: :link, linked_class: :V
    create_index "#{self.name}_idx", on: [ :in, :out ]
  end
=begin
  Instantiate a new Edge between two Vertices 

  Parameter: unique: (true)
  
  In case of an existing Edge just update its Properties.
  
  The parameters »from« and »to« can take a list of model-records. Then subsequent edges are created.
   :call-seq:
    Model.create from:, to:, unique: false, attributes:{}
=end


  def create  **keyword_arguments
    puts "Creating an Edge!!"
    new_edge = db.create_edge self, **keyword_arguments
    new_edge =  new_edge.pop if new_edge.is_a?( Array) && new_edge.size == 1
  #  [:from,:to].each do |y|
#    p  keyword_arguments[y].is_a?(Array) ? keyword_arguments[y].map{|x| "#{y}::ka: #{x.class}" }.join(",") :  "KA:#{keyword_arguments[y].inspect}"
 #     keyword_arguments[y].is_a?(Array) ? keyword_arguments[y].each( &:reload! ) : keyword_arguments[y].reload!
#      end
      new_edge
  end

end
