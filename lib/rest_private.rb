module RestPrivate
	private

	def translate_property_hash field, type: nil, linked_class: nil, **args
		type =  type.presence || args[:propertyType].presence || args[:property_type]
		linked_class = linked_class.presence || args[:linkedClass]
		if type.present?
		  if linked_class.nil?
		    {field => {propertyType: type.to_s.upcase}}
		  else
		    {field => {propertyType: type.to_s.upcase, linkedClass: classname(linked_class)}}
		  end
		end
	end

	def property_uri(this_classname)
	  if block_given?
	    "property/#{ @database }/#{this_classname}/" << yield
	  else
	    "property/#{ @database }/#{this_classname}"
	  end
	end

	def self.simple_uri *names
	  names.each do |name|
	    m_name = ("#{name.to_s}_uri").to_sym
	    define_method(m_name) do |&b|
	      if b
	        "#{name.to_s}/#{@database}/#{b.call}"
	      else
	        "#{name.to_s}/#{@database}"
	      end # branch
	    end
	  end
	end

	def self.sql_uri *names
	  names.each do |name|
	    define_method(("#{name.to_s}_sql_uri").to_sym) do
	      "#{name.to_s}/#{@database}/sql/"
	    end
	  end
	end

	simple_uri :database, :document, :class, :batch, :function
	sql_uri :command, :query

end
