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
  
  ##################################### CLASS VARIABLES #############################################
  
  @@mx = Mutex.new
  @@proxied_instance_methods = {}
  @@proxied_class_methods = {}
  @@tmp_binding = nil
  
  #################################### SOME HELPER METHODS ##########################################
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
  
  
  def self.classes_with_proxied_class_methods
    @@mx.synchronize do
      return @@proxied_class_methods.keys.collect{|k| Class.const_get(k)}
    end
  end
  
  def self.proxied_class_methods_for(klass)
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    @@mx.synchronize do
      meth_hash_for_klass = @@proxied_class_methods[klass.name.to_sym]
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
  
  def self.tmp_binding
    @@tmp_binding
  end
  
  protected
  def self.capture_tmp_binding!(bndg)
    @@tmp_binding = bndg
  end
  
  def self.reset_tmp_binding!
    @@tmp_binding = nil
  end
  
  ####################################### MAIN STUFF #################################################
  public
  
  # "Tap" into instance method calls - subvert original method with the supplied block; preserve
  # reference to the original method so that it can still be called or restored later on.
  #
  # Common idiom:
  # MethodProxy.proxy_instance_method(SomeClass, :some_instance_method) do |obj, original_instance_meth, *args|
  #
  #   # do stuff before calling original method
  #     ... ... ...
  #
  #   # call the original method (already bound to object obj), with supplied arguments
  #   result = original_instance_meth.call(*args)
  #
  #   # do stuff after calling original method
  #     ... ... ...
  #
  #   # return the actual return value
  #   result
  # end
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
  
  # Restore the original instance method for objects of class klass
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
  
  # "Tap" into class method calls - subvert original method with the supplied block; preserve
  # reference to the original method so that it can still be called or restored later on.
  #
  # Common idiom:
  # MethodProxy.proxy_class_method(SomeClass, :some_class_method) do |klass, original_class_meth, *args|
  #
  #   # do stuff before calling original method
  #     ... ... ...
  #
  #   # call original method (already bound to SomeClass), with supplied arguments
  #   result = original_class_meth.call(*args)
  #
  #   # do stuff after calling original method
  #     ... ... ...
  #
  #   # return the actual return value
  #   result
  # end
  def self.proxy_class_method klass, meth, &block
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    raise "must supply block argument" unless block_given?
    
    @@mx.synchronize do
      proc = Proc.new(&block)
      
      capture_tmp_binding! binding
      
      @@proxied_class_methods[klass.name.to_sym] ||= {}
    
      class << klass
        
        klass, meth, proc = eval "[klass, meth, proc]", MethodProxy.tmp_binding
        
        self.instance_eval do
          if @@proxied_class_methods[klass.name.to_sym][meth]
            raise ::MethodProxyException, "The method has already been proxied"
          end
          @@proxied_class_methods[klass.name.to_sym][meth] = instance_method meth
        end
      
        remove_method meth
      
        self.instance_eval do
          define_method(meth) do |*args|
            ret = proc.call(self, @@proxied_class_methods[klass.name.to_sym][meth].bind(self), *args)
            return ret
          end
        end
      end
      
      reset_tmp_binding!
    end
  end
  
  # Restore the original class method for klass
  def self.unproxy_class_method klass, meth
    raise "klass argument must be a Class" unless klass.is_a?(Class) || klass.is_a?(Module)
    raise "method argument must be a Symbol" unless meth.is_a?(Symbol)
    
    @@mx.synchronize do
      return unless (class_entries = @@proxied_class_methods[klass.name.to_sym])
      return unless (orig_unbound_meth = class_entries[meth])
    
      capture_tmp_binding! binding
    
      class << klass
        meth, orig_unbound_meth = eval "[meth, orig_unbound_meth]", MethodProxy.tmp_binding
        self.instance_eval do
          define_method meth, orig_unbound_meth
        end
      end
      
      reset_tmp_binding!
      
      # clean up storage
      @@proxied_class_methods[klass.name.to_sym].delete(meth)
      remaining_proxied_class_methods = @@proxied_class_methods[klass.name.to_sym]
      @@proxied_class_methods.delete(klass.name.to_sym) if remaining_proxied_class_methods.empty?
    end
  end
end
