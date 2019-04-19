require 'active_model'
require 'active_support/concern'
#require 'active_support/hash_with_indifferent_access'

module ActiveOrient
  module BaseProperties
    extend ActiveSupport::Concern

# Default presentation of ActiveOrient::Model-Objects

    def to_human
      "<#{self.class.to_s.demodulize}: " + content_attributes.map do |attr, value|
	v= case value
	   when ActiveOrient::Model
	     "< #{self.class.to_.demodulize} : #{value.rrid} >"
		 when OrientSupport::Array
			 value.rrid #.to_human #.map(&:to_human).join("::")
	   else
	     value.from_orient
	   end
        "%s : %s" % [ attr, v]  unless v.nil?
      end.compact.sort.join(', ') + ">".gsub('"' , ' ')
    end

# Comparison support

    def content_attributes  # :nodoc:
#      HashWithIndifferentAccess[attributes.reject do |(attr, _)|
      Hash[attributes.reject do |(attr, _)|
        attr.to_s =~ /(_count)\z/ || attr.to_s =~ /^in_/ || attr.to_s =~ /^out_/ || [:created_at, :updated_at, :type, :id, :order_id, :contract_id].include?(attr.to_sym)
      end]
    end

# return a string ready to include as embedded document
		def embedded
			{ "@type" => 'd', "@class" => self.class.ref_name }
			            .merge(content_attributes)
			            .map{|y,x| z='';  z  <<  y.to_s << ': ' << x.to_or.to_s }.join(' ,')
			
		end

# Update nil attributes from given Hash or model

    def update_missing attrs  # :nodoc:
      attrs = attrs.content_attributes unless attrs.kind_of?(Hash)
      attrs.each{|attr, val| send "#{attr}=", val if send(attr).blank?}
      self # for chaining
    end

# Default Model comparison

    def == other  # :nodoc:
      case other
      when String # Probably a link or a rid
        "##{rid}" == other || rid == other
      when  ActiveOrient::Model
	      rid == other.rid
      else
        content_attributes.keys.inject(true){ |res, key|
          res && other.respond_to?(key) && (send(key) == other.send(key))
        }
      end
    end

# Default attributes support

    def default_attributes
			{}
      #{:created_at => DateTime.now }
    end

    def set_attribute_defaults # :nodoc:
      default_attributes.each do |key, val|
        self.send("#{key}=", val) if self.send(key).nil?
      end
    end

    included do
      after_initialize :set_attribute_defaults

# Class macros

      def self.prop *properties   # :nodoc: 
        prop_hash = properties.last.is_a?(Hash) ? properties.pop : {}
        properties.each { |names| define_property names, nil }
        prop_hash.each { |names, type| define_property names, type }
      end

      def self.define_property names, body  # :nodoc:
        aliases = [names].flatten
        name = aliases.shift
        instance_eval do
          define_property_methods name, body
          aliases.each do |ali|
            alias_method "#{ali}", name
            alias_method "#{ali}=", "#{name}="
          end
        end
      end

      def self.define_property_methods name, body={}   # :nodoc:
        case body
        when '' # default getter and setter
          define_property_methods name

        when Array # [setter, getter, validators]
          define_property_methods name,
            :get => body[0],
            :set => body[1],
            :validate => body[2]

        when Hash # recursion base case
	#  puts "NAME: "+name.to_s
	#	     puts "BODY::"+body.inspect
				 getter = case # Define getter
									when body[:get].respond_to?(:call)
										body[:get]
									when body[:get]
										proc{self[name].send "to_#{body[:get]}"}
									else
										proc{self[name]}
									end
				 define_method name, &getter if getter
				 setter = case # Define setter
									when body[:set].respond_to?(:call)
										body[:set]
									when body[:set]
										proc{|value| self[name] = value.send "to_#{body[:set]}"}
									else
										proc{|value| self[name] = value} # p name, value;
									end
				 define_method "#{name}=", &setter if setter

          # Define validator(s)
          [body[:validate]].flatten.compact.each do |validator|
            case validator
            when Proc
              validates_each name, &validator
            when Hash
              validates name, validator.dup
            end
          end

# todo define self[:name] accessors for :virtual and :flag properties

        else # setter given
          define_property_methods name, :set => body, :get => body
        end
      end

      unless defined?(ActiveRecord::Base) && ancestors.include?(ActiveRecord::Base)
        prop :created_at #, :updated_at
      end

    end # included
  end # module BaseProperties
end
