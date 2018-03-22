require File.realpath(File.dirname(__FILE__) + "/../lib/bitwarden_ruby.rb")
[
  ["amazon.de", "amazon.it"]
].each do |d|
  geq = GlobalEquivalentDomain.new
  geq.domains = d.to_json
  geq.save
end
