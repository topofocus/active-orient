source "https://rubygems.org"
gemspec
gem 'activesupport' # ,  "~>4.2"
gem 'activemodel' #,   "~>4.2"
gem 'rest-client'  , :git => 'git://github.com/rest-client/rest-client.git'
gem 'nokogiri', '~> 1.6.6' #, :git => 'git://github.com/sparklemotion/nokogiri.git'
gem 'orientdb' , :path => '/home/topo/orientdb-jruby' , :platforms => :jruby
#gem 'orientdb' , :git => 'git://github.com/topofocus/orientdb-jruby.git', :branch => '2.1.2', :platforms => :jruby
group :development, :test do
	gem "awesome_print"
	gem "rspec"
	gem 'rspec-legacy_formatters'
	gem 'rspec-its'
	gem 'rspec-collection_matchers'
	gem 'rspec-context-private'
	gem 'guard-jruby-rspec', :platforms => :jruby, :git => 'git://github.com/jkutner/guard-jruby-rspec.git'
	gem 'guard'#, :platforms => :ruby
	gem 'guard-rspec'
##	gem 'database_cleaner'
	gem 'rb-inotify'
	gem 'pry'
end
