class GuineaPig
  def lr_instance_method a, b
    return "#{a}-#{b}"
  end
  
  def self.lr_class_method c, d
    return "#{c}$#{d}"
  end
end

require File.join(File.expand_path(File.dirname(__FILE__)), "../lib/method_proxy")
require "test/unit"

class MethodProxyTest < Test::Unit::TestCase
  def test_proxy_unproxy_instance_method
    gpig = GuineaPig.new
    assert_equal "2-3", gpig.lr_instance_method(2, 3)
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(GuineaPig)
    
    MethodProxy.proxy_instance_method(GuineaPig, :lr_instance_method) do |obj, meth, a, b|
      res = meth.call a, b
      next "<#{res}>"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    assert_equal "<2-3>", gpig.lr_instance_method(2, 3)
    assert [GuineaPig].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [:lr_instance_method], MethodProxy.proxied_instance_methods_for(GuineaPig)
    
    MethodProxy.unproxy_instance_method(GuineaPig, :lr_instance_method)
    assert_equal "2-3", gpig.lr_instance_method(2, 3)
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(GuineaPig)
  end
  
  def test_proxy_unproxy_class_method
    assert_equal "4$5", GuineaPig.lr_class_method(4, 5)
    assert [].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [], MethodProxy.proxied_class_methods_for(GuineaPig)

    MethodProxy.proxy_class_method(GuineaPig, :lr_class_method) do |obj, meth, c, d|
      res = meth.call c, d
      next "[#{res}]"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    assert_equal "[4$5]", GuineaPig.lr_class_method(4, 5)
    assert [GuineaPig].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [:lr_class_method], MethodProxy.proxied_class_methods_for(GuineaPig)
    
    MethodProxy.unproxy_class_method(GuineaPig, :lr_class_method)
    assert_equal "4$5", GuineaPig.lr_class_method(4, 5)
    assert [].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [], MethodProxy.proxied_class_methods_for(GuineaPig)
  end
end