class LabRabbit
  def lr_instance_method a, b
    return "#{a}-#{b}"
  end
  
  def self.lr_class_method c, d
    return "#{c}$#{d}"
  end
end

require File.join(File.expand_path(File.dirname(__FILE__)), "method_proxy")
require "test/unit"

class MethodProxyTest < Test::Unit::TestCase
  def test_proxy_unproxy_instance_method
    lrabbit = LabRabbit.new
    assert_equal "2-3", lrabbit.lr_instance_method(2, 3)
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(LabRabbit)
    
    MethodProxy.proxy_instance_method(LabRabbit, :lr_instance_method) do |obj, meth, a, b|
      res = meth.call a, b
      next "<#{res}>"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    assert_equal "<2-3>", lrabbit.lr_instance_method(2, 3)
    assert [LabRabbit].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [:lr_instance_method], MethodProxy.proxied_instance_methods_for(LabRabbit)
    
    MethodProxy.unproxy_instance_method(LabRabbit, :lr_instance_method)
    assert_equal "2-3", lrabbit.lr_instance_method(2, 3)
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(LabRabbit)
  end
  
  def test_proxy_unproxy_class_method
    assert_equal "4$5", LabRabbit.lr_class_method(4, 5)

    MethodProxy.proxy_class_method(LabRabbit, :lr_class_method) do |obj, meth, c, d|
      res = meth.call c, d
      next "[#{res}]"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    assert_equal "[4$5]", LabRabbit.lr_class_method(4, 5)

    MethodProxy.unproxy_class_method(LabRabbit, :lr_class_method)
    assert_equal "4$5", LabRabbit.lr_class_method(4, 5)
  end
end