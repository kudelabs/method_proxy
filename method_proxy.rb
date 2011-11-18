class ::MethodProxyException < Exception

end

# Functionality of this class allows to easily proxy instance method meth calls on objects
# of class klass. 
class ::MethodProxy
  # Proxy instance method meth calls on objects of class klass. Replaces original method
  # meth with call to Proc made from the supplied block. The block should accept the following
  # arguments:
  #   1) object on which the call is made;
  #   2) original method bound to the object on which call is made;
  #   3-...) *args - arguments of original function call.
  #
  # Example.
  # Say, we want to print arguments and return values of "some_method" method on objects of
  # class SomeClass, to STDOUT. The way to do this with proxy_instance_method is:
  # MethodProxy.proxy_instance_method(SomeClass, :some_method) do |obj, bound_meth, *args|
  #   puts "\nMethod call to SomeClass#some_method received."
  #   puts "Arguments: #{args.inspect}"
  #   puts "Executing..."
  #   ret = bound_meth.call(*args)
  #   puts "Return value: #{ret.inspect}.\n"
  # end
  #
  
  @@proxied_methods = {}
  @@proxied_class_methods = {}
  
  def self.proxy_instance_method(klass, meth, &block)
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    raise "must supply block argument" unless block_given?
    klass.class_eval %(
      @@proxied_methods ||= {}
      if @@proxied_methods[meth]
        raise ::MethodProxyException, "The method has already been proxied"
      end
      @@proxied_methods[meth] = instance_method meth
      undef_method(meth)
      
      proc = Proc.new(&block)
      
      define_method meth do |*args|
        ret = proc.call(self, @@proxied_methods[meth].bind(self), *args)
        return ret
      end
    )
  end

  def self.unproxy_instance_method(klass, meth)
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    
    klass.class_eval %(
      return unless class_variable_defined?("@@proxied_methods")
      return unless @@proxied_methods[meth].is_a?(UnboundMethod)    # pass-through rather than raise
      
      define_method(meth, @@proxied_methods[meth])
    )
  end
  
  #TODOs: 
  # - move storage of proxied methods entirely into MethodProxy class rather than store them inside proxied classes;
  # - switch to use of class methods instead of global variables
  def self.proxy_class_method klass, meth, &block
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    raise "must supply block argument" unless block_given?
    
    $method_proxy_meth = meth
    $method_proxy_klass = klass
    $method_proxy_proc = Proc.new(&block)
    
    class << klass
      self.instance_eval do
        @@proxied_class_methods[$method_proxy_klass] ||= {}
        if @@proxied_class_methods[$method_proxy_klass][$method_proxy_meth]
          raise ::MethodProxyException, "The method has already been proxied"
        end
        @@proxied_class_methods[$method_proxy_klass][$method_proxy_meth] = instance_method $method_proxy_meth
      end
      
      remove_method $method_proxy_meth
      
      self.instance_eval do
        define_method($method_proxy_meth) do |*args|
          ret = $method_proxy_proc.call(self, @@proxied_class_methods[$method_proxy_klass][$method_proxy_meth].bind(self), *args)
          return ret
        end
      end
    end
    
    
  end
end
