module OrientSupport
	class Query
		include Support


		# initialize with
		# Query.new :s)elect, :t)raverse, :m)atch
		# Query.new select: '', where: { a: 5 } 
		def initialize kind =  ''
		@kind = 	case kind.to_s[0]
			when 's'
				'SELECT'
			when 'm'
				'MATCH'
			when 't'
				'TRAVERSE'
			else
				''
			end

		end


def modify
    c = @uri.clone
    yield c
    Iri.new(c)
  end

  def modify_query
    modify do |c|
      params = CGI.parse(@uri.query || '').map { |p, a| [p.to_s, a.clone] }.to_h
      yield(params)
      c.query = URI.encode_www_form(params)
    end
  end
end


	 def cut(path = '/')
    modify do |c|
      c.query = nil
      c.path = path
      c.fragment = nil
    end
end

	 
  # Replace the query part of the URI.
  def query(val)
    modify do |c|
      c.query = val
    end
end

	# Replace query argument(s).
  #
  #  Iri.new('https://google.com?q=test').over(q: 'hey you!')
  #
  def over(hash)
    modify_query do |params|
      hash.each do |k, v|
        params[k.to_s] = [] unless params[k]
        params[k.to_s] = [v]
      end
    end
end


	  # Makes a new object.
  #
  # You can even ignore the argument, which will produce an empty URI.
  def initialize(uri = '')
    @uri = URI(uri)
  end

  # Convert it to a string.
  def to_s
    @uri.to_s
  end

  # Convert it to an object of class +URI+.
  def to_uri
    @uri.clone
end



	end
end


