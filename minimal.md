## Minimal Setup 

The gem may be used without object-mappings and external configuration

This is the minimal configuration:

```ruby


require 'bundler/setup'
require 'active-orient'
require 'logger'

logger = Logger.new '/dev/stdout'
ActiveOrient::Model.logger = logger
ActiveOrient::OrientDB.logger = logger
ActiveOrient.default_server = {server: 'localhost', user: 'root', password: 'xxx', database: 'gems', port: 2480}
ActiveOrient.database = :gems
ActiveOrient::Model.keep_models_without_file = true
ActiveOrient::Model.model_dir = '.'
ActiveOrient::Init.define_namespace 

ORD = ActiveOrient::OrientDB.new preallocate: true

# require model files after initializing the database
gem_root =  `bundle show active-orient`[0..-2]
require "#{gem_root}/lib/model/edge.rb"
require "#{gem_root}/lib/model/vertex.rb"




```

After that, one can check if anything works by printing the preallocated databases

```ruby
puts ORD.class_hierarchy.to_yaml
# and
puts ActiveOrient::show_classes
```


