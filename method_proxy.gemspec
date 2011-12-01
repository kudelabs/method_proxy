Gem::Specification.new do |s|
  s.name        = 'method_proxy'
  s.version     = '0.2.1'
  s.date        = '2011-12-01'
  s.summary     = "Ruby method call interception tool."
  s.description = %q(Provides convenient means of "taping" into instance or class method calls. The intercepting
code is provided with reference to the object, reference to the original method and list of arguments.)
  s.authors     = ["Jevgenij Solovjov"]
  s.email       = 'jevgenij@kudelabs.com'
  s.files       = ["lib/method_proxy.rb", "test/method_proxy_test.rb", "README"]
  s.homepage    = "https://github.com/kudelabs/method_proxy"
end