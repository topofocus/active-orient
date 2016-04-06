# NEW

def create_general_class classes, behaviour = "NORMALCLASS", extend_class, properties: nil
  if @classes_available.nil?
    @classes_available = get_database_classes requery: true
    @classes_available = @classes_available.map!{|x| x.downcase}
  end

  begin
    consts = Array.new

    if classes.is_a? Array
      if behaviour == "NORMALCLASS"
        classes.each do |singleclass|
          consts |= create_general_class singleclass, properties: properties
        end
      else
        classes.each do |singleclass|
          consts |= create_general_class singleclass, "EXTENDEDCLASS", extend_class, properties: properties
        end
      end

    elsif classes.is_a? Hash
      classes.keys.each do |superclass|
        consts |= create_general_class superclass, "SUPERCLASS"
        consts |= create_general_class classes[superclass], "EXTENDEDCLASS", superclass, properties: properties
      end

    else
      name_class = classes.to_s.camelize
      unless @classes_available.include?(name_class.downcase)

        if behaviour == "NORMALCLASS"
          command = "CREATE CLASS #{name_class}"
        elsif behaviour = "SUPERCLASS"
          command = "CREATE CLASS #{name_class} ABSTRACT"
        elsif behaviour = "EXTENDEDCLASS"
          name_superclass = extend_class.to_s.camelize
          command = "CREATE CLASS #{name_class} EXTENDS #{name_superclass}"
        end

        execute transaction: false do
          { type:     "cmd",
            language: "sql",
            command:  command}
        end

        @classes_available << name_class.downcase

        # Add properties
        unless properties.nil?
          create_properties temp_class, properties
        end

      end
      temp_class = ActiveOrient::Model.orientdb_class(name: name_class)
      consts << temp_class
      return consts
    end
  rescue RestClient::InternalServerError => e
    logger.progname = 'RestCreate#CreateGeneralClass'
    response = JSON.parse(e.response)['errors'].pop
    logger.error{"#{response['content'].split(':').last }"}
    nil
  end
end
alias create_classes create_general_class

# OLD

def create_general_class classes, properties: nil
    begin
      get_database_classes requery: true
      consts = Array.new
      execute transaction: false do
        class_cmd = -> (s,n) do
      	  n = n.to_s.camelize
      	  consts << ActiveOrient::Model.orientdb_class(name: n)
          classes_available = get_database_classes.map{|x| x.downcase}
      	  unless classes_available.include?(n.downcase)
      	    {type: "cmd", language: 'sql', command: "CREATE CLASS #{n} EXTENDS #{s}"}
          end
    	  end  ## class_cmd

    	  if classes.is_a?(Array)
    	    classes.map do |n|
    	      n = n.to_s.camelize
    	      consts << ActiveOrient::Model.orientdb_class(name: n)
            classes_available = get_database_classes.map{|x| x.downcase}
        	  unless classes_available.include?(n.downcase)
    		      {type: "cmd", language: 'sql', command: "CREATE CLASS #{n}"}
    	      end
    	    end
    	  elsif classes.is_a?(Hash)
    	    classes.keys.map do |superclass|
    	      items = Array.new
    	      superClass = superclass.to_s.camelize
            unless get_database_classes.flatten.include?(superClass)
    	        items << {type: "cmd", language: 'sql', command:  "CREATE CLASS #{superClass} ABSTRACT"}
            end
    	      items << if classes[superclass].is_a?(String) || classes[superclass].is_a?(Symbol)
    		      class_cmd[superClass, classes[superclass]]
    	      elsif classes[superclass].is_a?(Array)
    		      classes[superclass].map{|n| class_cmd[superClass, n]}
    	      end
            items  # returnvalue
    	    end.flatten
    	  end.compact # erase nil-entries, in case the class is already allocated
      end
    # refresh cached class-informations
      classes_available = get_database_classes requery: true

    # Add properties
      unless properties.nil?
        classes_available.map!{|x| x.downcase}
        consts = Array.new
        if classes.is_a?(Hash)
          superclass = classes.keys[0]
          classes = [classes[superclass]]
        end
        classes.each do |n|
          if classes_available.include?(n.downcase)
            temp_class = ActiveOrient::Model.orientdb_class(name: n)
            create_properties temp_class, properties
            consts << temp_class
          end
        end
      end

    # returns an array of allocated Constants/Classes
      consts
    rescue RestClient::InternalServerError => e
      logger.progname = 'RestCreate#CreateGeneralClass'
      response = JSON.parse(e.response)['errors'].pop
      logger.error{"#{response['content'].split(':').last }"}
      nil
    end
  end
  alias create_classes create_general_class
