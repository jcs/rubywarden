require File.realpath(File.dirname(__FILE__) + "/../lib/bitwarden_ruby.rb")
[
  ["amazon.de", "amazon.it"]
].each do |d|
  GlobalEquivalentDomain.create domains: d
end
