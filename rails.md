# Active Orient and Rails

There are only a few steps nessesary, to use Orientdb via ActiveOrient in Rails.

Based on a Rails 5 installation

```ruby
  rvm install 2.4
  rvm use 2.4
  gem install bundler
  gem install nokogiri
  gem install rails
  rails -v   # Rails 5.0.1

```

create your working directory and initialize the system

```ruby
mkdir rails_project; cd rails_project
rails -OCT .
```
This initializes a Rails-Stack, without active-record, action-cable and the test-suite.
(We will use rspec later)

This can be checked by inspecting «/config/application.rb «
 
```ruby
rails s puma
```
should work at this stage.

## Modify the Gemfile
We have to tell rails to use orientdb and active-orient

```
echo " gem 'active-orient' , :path => '/home/your_cloned_active_orient_path/activeorient' " >> Gemfile
# or

echo " gem 'active-orient' , :git => 'https://github.com/topofocus/active-orient.git' " >> Gemfile
```

After that, copy 

* __active_orient/rails/activeorient.rb__   to   /config/initializers  in the rails-project dir
* __active_orient/rails/connect.yml__ to /config
* __active_orient/rails/config.yml__ to /config

and modify the yml-files accordingly.

Now its time to run the  bundler

```
bundle install & bundle update
```

The database should be present in the rails console
```ruby
rails c

V.count
V.first
E.count
puts ActiveOrient::Model.allocated_classes.map{|x,y| "#{"%15s"% x} ->  #{y.to_s}" }.join("\n")

```
should work.

**Notice** The spring-facility is running in the background. Stop the server prior reloading
the console ( ./bin/spring stop ). 

The final step is to generate Model-Files. In «/config/config.yml» the «:model_dir»-var points to
the location of the model-files. The default is 'lib/orient'. 

Upon startup this directory is scanned for autoloading database-files. 

After envoking the rails console, the logfile displays sucessfully loaded and missing files, ie.

```
14.01.(08:28:45) INFO->ModelClass#RequireModelFile:..:model-file not present: /home/topo/workspace/orient-rails/lib/orient/followed_by.rb
14.01.(08:28:45) INFO->ModelClass#RequireModelFile:..:/home/topo/workspace/orient-rails/lib/orient/v.rb sucessfully loaded
```

## Model-file Examlple

To query the GratefulDeadConcerts Database, this can be used in «v.rb»

```
1 class V 
2        def  self.artists **attributes 
3          names 'artist', **attributes
4        end
5        
6        def  self.songs **attributes 
7          names 'song', **attributes
8        end
9        
10        def self.types
11          oo =  OrientSupport::OrientQuery
12          this_query = oo.new  distinct: [:type, :a ]
13          query_database( this_query ).a
14        end
15 private
16        def  self.names  type, sort: :asc, limit: 20, skip: 0
17          puts "in names"
18          oo =  OrientSupport::OrientQuery
19          query_database  oo.new( where: {type: type }, 
20                                 order: { name: sort } ,
21                                 limit: limit ,
22                                 skip: skip )
23        end
24 end

```

Now 

```ruby
  V.types
  V.artists limit: 15, skip: 34, sort: :desc 
```
can be used everywhere.



