class GuineaPig
  def gp_instance_method a, b
    return "#{a}-#{b}"
  end
  
  def gp_instance_method_w_block a, b, &block
    interm = "*#{a}*#{b}*"
    res = yield interm
    res
  end
  
  def self.gp_class_method c, d
    return "#{c}$#{d}"
  end
  
  def self.gp_class_method_w_block c, d, &block
    interm = "-=#{c}O#{d}=-"
    res = yield interm
    res
  end
end

require File.join(File.expand_path(File.dirname(__FILE__)), "../lib/method_proxy")
require "test/unit"

class MethodProxyTest < Test::Unit::TestCase
  def test_proxy_unproxy_instance_method
    gpig = GuineaPig.new
    assert_equal "2-3", gpig.gp_instance_method(2, 3)
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(GuineaPig)
    
    MethodProxy.proxy_instance_method(GuineaPig, :gp_instance_method) do |obj, meth, a, b|
      res = meth.call a, b
      next "<#{res}>"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    assert_equal "<2-3>", gpig.gp_instance_method(2, 3)
    assert [GuineaPig].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [:gp_instance_method], MethodProxy.proxied_instance_methods_for(GuineaPig)
    
    MethodProxy.unproxy_instance_method(GuineaPig, :gp_instance_method)
    assert_equal "2-3", gpig.gp_instance_method(2, 3)
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(GuineaPig)
  end
  
  def test_proxy_unproxy_instance_method_w_block
    gpig = GuineaPig.new
    before_res = gpig.gp_instance_method_w_block(6, 7) do |interm|
      "#{interm}<-->#{interm}"
    end
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(GuineaPig)
    assert_equal "*6*7*<-->*6*7*", before_res
    
    MethodProxy.proxy_instance_method(GuineaPig, :gp_instance_method_w_block) do |obj, meth, a, b, &block|
      res = meth.call a, b, &block
      next "!!!__#{res}__!!!"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    
    after_res = gpig.gp_instance_method_w_block(6, 7) do |interm|
      "#{interm}<-->#{interm}"
    end
    
    assert_equal "!!!__*6*7*<-->*6*7*__!!!", after_res
    assert [GuineaPig].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [:gp_instance_method_w_block], MethodProxy.proxied_instance_methods_for(GuineaPig)
    
    MethodProxy.unproxy_instance_method(GuineaPig, :gp_instance_method_w_block)
    after_un_res = gpig.gp_instance_method_w_block(6, 7) do |interm|
      "#{interm}<-->#{interm}"
    end
    assert_equal before_res, after_un_res
    assert [].eql?(MethodProxy.classes_with_proxied_instance_methods)
    assert_equal [], MethodProxy.proxied_instance_methods_for(GuineaPig)
  end
  
  def test_proxy_unproxy_class_method
    assert_equal "4$5", GuineaPig.gp_class_method(4, 5)
    assert [].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [], MethodProxy.proxied_class_methods_for(GuineaPig)

    MethodProxy.proxy_class_method(GuineaPig, :gp_class_method) do |obj, meth, c, d|
      res = meth.call c, d
      next "[#{res}]"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    assert_equal "[4$5]", GuineaPig.gp_class_method(4, 5)
    assert [GuineaPig].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [:gp_class_method], MethodProxy.proxied_class_methods_for(GuineaPig)
    
    MethodProxy.unproxy_class_method(GuineaPig, :gp_class_method)
    assert_equal "4$5", GuineaPig.gp_class_method(4, 5)
    assert [].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [], MethodProxy.proxied_class_methods_for(GuineaPig)
  end
  
  def test_proxy_unproxy_class_method_w_block
    before_res = GuineaPig.gp_class_method_w_block(8, 9) do |interm|
      "#{interm}>--<#{interm}"
    end
    assert_equal "-=8O9=->--<-=8O9=-", before_res
    assert [].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [], MethodProxy.proxied_class_methods_for(GuineaPig)
    
    MethodProxy.proxy_class_method(GuineaPig, :gp_class_method_w_block) do |obj, meth, a, b, &block|
      res = meth.call a, b, &block
      next "???__#{res}__???"   # within Proc's should be 'next' instead of 'return' -- in order to avoid returning from the caller method
    end
    
    after_res = GuineaPig.gp_class_method_w_block(8, 9) do |interm|
      "#{interm}>--<#{interm}"
    end
    
    assert_equal "???__-=8O9=->--<-=8O9=-__???", after_res
    assert [GuineaPig].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [:gp_class_method_w_block], MethodProxy.proxied_class_methods_for(GuineaPig)
    
    MethodProxy.unproxy_class_method(GuineaPig, :gp_class_method_w_block)
    after_un_res = GuineaPig.gp_class_method_w_block(8, 9) do |interm|
      "#{interm}>--<#{interm}"
    end
    assert_equal before_res, after_un_res
    assert [].eql?(MethodProxy.classes_with_proxied_class_methods)
    assert_equal [], MethodProxy.proxied_class_methods_for(GuineaPig)
  end
end
