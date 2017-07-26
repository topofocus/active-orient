# Active Orient and Rails

The usage of Orientdb via ActiveOrient in Rails requires just a few steps.
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
rails new -OCT .
```
This initializes a Rails-Stack, without active-record, action-cable and the test-suite.
(We will use rspec later)

This can be checked by inspecting «/config/application.rb «
 
```ruby
rails s puma
```
should work at this stage.

## Modify the Gemfile
Inform rails to use orientdb and active-orient

```
echo " gem 'active-orient' , :path => '/home/your_cloned_active_orient_path/activeorient' " >> Gemfile
# or

echo " gem 'active-orient' , :git => 'https://github.com/topofocus/active-orient.git' " >> Gemfile

```

Run the  bundler

```
bundle install & bundle update
```
## Copy Initializer and Configuration Files
change to the base-dir of the gem
-->  bundle show active-orient
then copy 

* rails/activeorient.rb   to   config/initializers  in the rails-project dir
* rails/connect.yml to config  in the rails project
* rails/config.yml  to config   in the rails project

and modify the yml-files accordingly. 
(Depending on your settings, you might have to adjust tab-levels)


The database is present in the rails console, and 
```ruby
rails c
puts ActiveOrient:show_classes

V.count
V.first
E.count

```
should display details.


**Notice** The spring-facility is running in the background. Stop the server prior reloading
the console ( ./bin/spring stop ). 

## Model-files
The final step is to generate Model-Files. 

In «/config/config.yml» the «:model_dir»-var points to
the location of the model-files. The default is 'lib/orient'. Change to your needs.
Don't use the app directory, as its autoloaded too early. 

Upon startup, present model-classes are destroyed and overridden by present files in the autoload directory. 

After envoking the rails console, the logfile displays sucessfully loaded and missing files, ie.

```
14.01.(08:28:45) INFO->ModelClass#RequireModelFile:..:model-file not present: /home/topo/workspace/orient-rails/lib/orient/followed_by.rb
14.01.(08:28:45) INFO->ModelClass#RequireModelFile:..:/home/topo/workspace/orient-rails/lib/orient/v.rb sucessfully loaded
```

## Model-file Example

To query the GratefulDeadConcerts Database, «v.rb» hosts the essential model methods.
As always, use «def self.{method}« for class methods and simply «def {method}» for methods working on the record level.

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
12          this_query = oo.new  distinct: [:type, :a ]  # -->  "select distinct( type ) as a  " 
13          query_database( this_query ).a  # returns an array of types, i.e. ["artist", "song"] 
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
queries the database, fetches 15 artists. 

## Routing

for now, restful routing has some restrictions.

Rails-routing is depending on the "id"-attribute. Even if this is remapped to rid, the ressources-entries in "config/routes.rb" have to be modified by

```ruiby
resources  :{controller}, id: /[^\/]+/
```
this enables the usage of id: "xx:yy" 

In the controller the record is fetched as usual:
```ruby
def show
    @{your coice} = {ActiveOrient-Model-Class}.autoload_object params[:id]
end
```




