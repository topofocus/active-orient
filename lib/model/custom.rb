module CustomClass
=begin
The REST-Interface does not work with "select from SomeClass where a_property like 'pattern%' "

This is rewritten as 

  SomeClass.like "name = D*", order: 'asc'

The order-argument is optional, "asc" is the default.
This Primitiv-Version only accepts the wildcards "*" and "%" at the end of the seach-string.
The Wildcard can be omitted.

The method does not accept further arguments. 
=end
  def like operation, order: 'asc'
    # remove all spaces and split the resulting word
    p, s = operation.gsub(/\s+/, "").split("=")
    if ["%","*"].include?(s[-1])
      s.chop! 
    end

    q =  OrientSupport::OrientQuery.new where: { "#{p}.left(#{s.length})" => s } ,order: { p => order }
    query_database q

  end
end
