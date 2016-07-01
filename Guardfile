# A sample Guardfile
# More info at https://github.com/guard/guard#readme
def fire
  require "ostruct"

  # Generic Ruby apps
  rspec = OpenStruct.new
  rspec.spec = ->(m) { "spec/#{m}_spec.rb" }
  rspec.spec_dir = "spec"
  rspec.spec_helper = "spec/spec_helper.rb"


  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^spec/usecase/(.+).rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
end


interactor :simple
if RUBY_PLATFORM == 'java' 
guard( 'jruby-rspec') {fire}  #', :spec_paths => ["spec"]
else
guard( :rspec, cmd: "bundle exec rspec") { fire }
end
