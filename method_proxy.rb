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
  
  @@mx = Mutex.new
  @@proxied_instance_methods = {}
  @@proxied_class_methods = {}
  
  def self.classes_with_proxied_instance_methods
    @@mx.synchronize do
      return @@proxied_instance_methods.keys.collect{|k| Class.const_get(k)}
    end
  end
  
  def self.proxied_instance_methods_for(klass)
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    @@mx.synchronize do
      meth_hash_for_klass = @@proxied_instance_methods[klass.name.to_sym]
      return [] if !meth_hash_for_klass || meth_hash_for_klass.empty?
      return meth_hash_for_klass.keys
    end
  end
  
  
  #### WARNING: NON-THREAD-SAFE methods for internal use; generally, they should not be called by ####
  ####                                 any external code                                          ####
  def self.register_original_instance_method(klass, meth_name, meth_obj)
    @@proxied_instance_methods[klass.name.to_sym][meth_name] = meth_obj
  end
  
  def self.original_instance_method(klass, meth_name)
    @@proxied_instance_methods[klass.name.to_sym][meth_name]
  end
  ###################################################################################################
  
  def self.proxy_instance_method(klass, meth, &block)
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    raise "must supply block argument" unless block_given?
    
    proc = Proc.new(&block)
    
    @@mx.synchronize do
      @@proxied_instance_methods[klass.name.to_sym] ||= {}
      if @@proxied_instance_methods[klass.name.to_sym][meth]
        raise ::MethodProxyException, "The method has already been proxied"
      end
    
      klass.class_eval do
      
        MethodProxy.register_original_instance_method(klass, meth, instance_method(meth))
      
        undef_method(meth)
    
        define_method meth do |*args|
          ret = proc.call(self, MethodProxy.original_instance_method(klass, meth).bind(self), *args)
          return ret
        end
      end
    end
  end
  
  def self.unproxy_instance_method(klass, meth)
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    
    @@mx.synchronize do
      return unless @@proxied_instance_methods[klass.name.to_sym][meth].is_a?(UnboundMethod)    # pass-through rather than raise
      proc = @@proxied_instance_methods[klass.name.to_sym][meth]
    
      klass.class_eval{ define_method(meth, proc) }
      
      # clean up storage
      @@proxied_instance_methods[klass.name.to_sym].delete(meth)
      remaining_proxied_instance_methods = @@proxied_instance_methods[klass.name.to_sym]
      @@proxied_instance_methods.delete(klass.name.to_sym) if remaining_proxied_instance_methods.empty?
    end
  end
  
  #TODOs: 
  # - move storage of proxied methods entirely into MethodProxy class rather than store them inside proxied classes;
  # - switch to use of class methods instead of global variables
  def self.proxy_class_method klass, meth, &block
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    raise "must supply block argument" unless block_given?
    
    @@mx.synchronize do
      $method_proxy_meth = meth
      $method_proxy_klass = klass
      $method_proxy_proc = Proc.new(&block)
    
      @@proxied_class_methods[$method_proxy_klass.name.to_sym] ||= {}
    
      class << klass
        self.instance_eval do
          if @@proxied_class_methods[$method_proxy_klass.name.to_sym][$method_proxy_meth]
            raise ::MethodProxyException, "The method has already been proxied"
          end
          @@proxied_class_methods[$method_proxy_klass.name.to_sym][$method_proxy_meth] = instance_method $method_proxy_meth
        end
      
        remove_method $method_proxy_meth
      
        self.instance_eval do
          define_method($method_proxy_meth) do |*args|
            ret = $method_proxy_proc.call(self, @@proxied_class_methods[$method_proxy_klass.name.to_sym][$method_proxy_meth].bind(self), *args)
            return ret
          end
        end
      end
    end
  end
    
  def self.unproxy_class_method klass, meth
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    
    @@mx.synchronize do
      return unless (class_entries = @@proxied_class_methods[klass.name.to_sym])
      return unless (orig_unbound_meth = class_entries[meth])
    
      $orig_unbound_meth = orig_unbound_meth
      $method_proxy_meth = meth
    
      class << klass
        self.instance_eval do
          define_method $method_proxy_meth, $orig_unbound_meth
        end
      end
    end
  end
end
