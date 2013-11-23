require 'opal'
require 'opal-jquery'
require 'opal-sprockets'

desc "Build our app to build.js"
task :build do
  env = Opal::Environment.new
  env.append_path "app"
  
  File.open("built/fol.js", "w+") do |out|
    out << env["lambda"].to_s
    out << env["parser-nolib"].to_s
    out << env["util/permutations"].to_s
    out << env["inverse"].to_s
    out << env["main"].to_s
  end
end