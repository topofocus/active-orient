lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name        = "orientdb_time_graph"
  s.version	= File.open('VERSION').read.strip
  s.authors     = ["Hartmut Bischoff"]
  s.email       = ["topofocus@gmail.com"]
  s.homepage    = 'https://github.com/topofocus/active-orient/examples/time_graph'
  s.licenses    = ['MIT']
  s.summary     = 'Implementation of a time graph in active.orient'
  s.description = '' 
  s.platform	= Gem::Platform::RUBY
  s.required_ruby_version = '>= 2.2.5'
  s.date 	= Time.now.strftime "%Y-%m-%d"
  s.test_files  = `git ls-files -- {spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = "exe"
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
   
  s.add_development_dependency "bundler", "~> 1.8"
  s.add_dependency 'active-orient', "~> 0.5"

end
