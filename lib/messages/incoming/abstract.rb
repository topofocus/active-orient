
module OrientSupport
  module Messages
    module Incoming

      # Container for specific message classes, keyed by their message_ids
      Classes = {}

      class AbstractMessage < OrientSupport::Messages::AbstractMessage

        attr_accessor :socket


        # Create incoming message from a given source ( Socket or data Hash)
        def initialize source
          @created_at = Time.now
          if source.is_a?(Hash)  # Source is a @data Hash
            @data = source
          else # Source is a Socket
            @socket = source
            @data = Hash.new
            self.load
          end
	  @loading_completed =  false
        end

	def data_available?
	  @loading_completed
	end

	def read_data
	  ## should be overwritten
	end
        # Override the load method in your subclass to do actual reading into @data.
        def load
          if socket

            load_map *self.class.data_map
	    @loading_completed =  true
          else
            raise "Unable to load, no socket"
          end

        rescue => e
          error "Reading #{self.class}: #{e.class}: #{e.message}", :load, e.backtrace
        end

        # Load @data from the socket according to the given data map.
        #
        # map is a series of Arrays in the format of
        #   [ :name, :type ], [  :group, :name, :type]
        # type identifiers must have a corresponding read_type method on socket (read_int, etc.).
        # group is used to lump together aggregates, such as Contract or Order fields
        def load_map(*map)
          map.each do |instruction|
            # We determine the function of the first element
            head = instruction.first
            case head
            when Integer # >= Version condition: [ min_version, [map]]
              load_map *instruction.drop(1) if version >= head

            when Proc # Callable condition: [ condition, [map]]
              load_map *instruction.drop(1) if head.call

            when true # Pre-condition already succeeded!
              load_map *instruction.drop(1)

            when nil, false # Pre-condition already failed! Do nothing...

            when Symbol # Normal map
              group, name, type, block =
              if  instruction[2].nil? || instruction[2].is_a?(Proc)
                [nil] + instruction # No group, [ :name, :type, (:block) ]
              else
                instruction # [ :group, :name, :type, (:block)]
              end

              data = socket.__send__("read_#{type}", &block)
              if group
                @data[group] ||= {}
                @data[group][name] = data
              else
                @data[name] = data
              end
            else
              error "Unrecognized instruction #{instruction}"
            end
          end
        end

      end # class AbstractMessage
    end # module Incoming
  end # module Messages
end # module IB
