# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "orientdb_rest/version"

Gem::Specification.new do |s|
  s.name        = "orientdb_rest"
  s.version     = 0.1
  s.authors     = [" Hartmut Bischoff"]
  s.email       = ["topofocus@gmail.com"]
  s.homepage    = 'https://github.com/topofocus/orientdb_rest'
  s.licenses    = ['MIT']
  s.summary     = %q{REST-HTTP client for OrientDB Server}
  s.description = %q{This gem uses the OrientDB REST-HTTP-API to provide connectivity to an OrientDB Server}

#  s.rubyforge_project = "orientdb_client"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec,features}/*`.split("\n")
#  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'activesupport'
  s.add_dependency 'rest-client', :git => 'git://github.com/rest-client/rest-client.git'

end
