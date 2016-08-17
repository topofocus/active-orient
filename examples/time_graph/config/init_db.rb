# Execute with 
#  ActiveOrient::OrientSetup.init_database
#
module ActiveOrient
  module OrientSetup
    def self.init_database
      (logger= ActiveOrient::Base.logger).progname= 'OrientSetup#InitDatabase'
      vertexes =  ORD.class_hierarchy base_class: 'time_base'
						# because edges are not resolved because of the namingconvention
      edges = ORD.class_hierarchy base_class: 'E'
      logger.info{ " preallocated-database-classes: #{ORD.database_classes.join(" , ")} " }

      delete_class = -> (c,d) do 
	the_class = ActiveOrient::Model.orientdb_class( name: c, superclass: d)
	logger.info{  "The Class: "+the_class.to_s }
	the_class.delete_class
      end
      
      logger.info{ "  Deleting Class and Classdefinitions" }
      vertexes.each{|v| delete_class[ v, :time_base ]}
      delete_class[ :time_base, :V ] if defined?(TimeBase)
      edges.each{|e| delete_class[ e, :E ] }

      logger.info{ "  Creating Classes " }
      ORD.create_vertex_class :time_base		      # --> TimeBase
      # hour, day: month cannot be alloacated, because Day is a class of DateTime and thus reserved
      ORD.create_classes( :stunde, :tag, :monat ){ :time_base } # --> Hour, Day, Month
      TimeBase.create_property :value_string, type: :string  
      TimeBase.create_property :value, type: :string  
							     # modified naming-convention in  model/e.rb
      ORD.create_edge_class :time_of, :day_of	     # --> TIME_OF, :DAY_OF

      ORD.database_classes  # return_value
    end
  end
end
# to_do:  define validations
#  hour_class   = r.create_vertex_class "Hour", properties: {value_string: {type: :string}, value: {type: :integer}}
#  hour_class.alter_property property: "value", attribute: "MIN", alteration: 0
#  hour_class.alter_property property: "value", attribute: "MAX", alteration: 23
#
#  day_class    = r.create_vertex_class "Day", properties: {value_string: {type: :string}, value: {type: :integer}}
#  day_class.alter_property property: "value", attribute: "MIN", alteration: 1
#  day_class.alter_property property: "value", attribute: "MAX", alteration: 31
#
#  month_class  = r.create_vertex_class "Month", properties: {value_string: {type: :string}, value: {type: :integer}}
#  month_class.alter_property property: "value", attribute: "MIN", alteration: 1
#  month_class.alter_property property: "value", attribute: "MAX", alteration: 12
#

#  timeof_class = r.create_edge_class "TIMEOF"
