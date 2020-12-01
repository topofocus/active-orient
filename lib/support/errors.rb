module ActiveOrient
	module Error
  # Error handling
  class Error < RuntimeError
  end

  class ArgumentError < ArgumentError
  end

  class SymbolError < ArgumentError
  end

  class LoadError < LoadError
  end

  class ServerError < RuntimeError
  end
end # module IB
end
# Patching Object with universally accessible top level error method. 
# The method is used throughout the lib instead of plainly raising exceptions. 
# This allows lib user to easily inject user-specific error handling into the lib 
# by just replacing Object#error method.
def error message, type=:standard, backtrace=nil
  e = case type
  when :standard
    ActiveOrientOrient::Error.new message
  when :args
    ActiveOrient::ArgumentError.new message
  when :symbol
    ActiveOrient::SymbolError.new message
  when :load
    AcitveOrient::LoadError.new message
  when :server
    ActiveOrient::Error::ServerError.new message
  end
  e.set_backtrace(backtrace) if backtrace
  raise e
end

# resued from https://github.com/ib-ruby/ib-ruby
