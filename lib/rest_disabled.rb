=begin #nodoc#
If properties are allocated on class-level, they can be preinitialized using
this method.
This is disabled for now, because it does not seem nessesary
=end

def preallocate_class_properties o_class
  p= get_class_properties( o_class )['properties']
  unless p.nil? || p.blank?
    predefined_attributes = p.map do | property |
      [ property['name'] ,
      case property['type']
      when 'LINKMAP'
        Array.new
      when 'STRING'
        ''
      else
        nil
      end  ]
    end.to_h
  else
    {}
  end
end
