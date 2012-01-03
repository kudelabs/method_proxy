### WHAT'S THIS? 

'method_proxy' gem allows to 'tap' into instance method or class method calls 
on objects of specific class or on specific classes. 


### API 

* `MethodProxy.proxy_instance_method(SomeClass, :some_instance_method, &block)`

Replaces original instance method SomeClass#some_instance_method with method 
generated from supplied block. Supplied block should expect following 
arguments:
  1) object on which the call is made;
  2) original method bound to the object on which call is made;
  3-...) *args - arguments of original function call.

An important thing to remember, is the &block should not use 'return <result>' 
and should use 'next <result>' construct instead - as 'return' will result in 
exception:

LocalJumpError: unexpected return


* `MethodProxy.unproxy_instance_method(SomeClass, :some_instance_method)`

Restore original instance method SomeClass#some_instance_method.


* `MethodProxy.proxy_class_method(SomeClass, :some_class_method, &block)`

Replaces original class method with method generated from supplied block. 
Supplied block should expect following arguments:
  1) class on which the call is made;
  2) original method bound to that class;
  3-...) *args - arguments of original function call.

Just like in case of proxy_instance_method, &block should use 'next <result>' 
construct instead of 'return <result>' or LocalJumpError will be raised.


* `MethodProxy.unproxy_class_method(SomeClass, :some_class_method)`
Restore original class method SomeClass.some_class_method.


* `MethodProxy.classes_with_proxied_instance_methods`

Returns Array of classes that have at least one instance method tapped into by 
MethodProxy.


* `MethodProxy.proxied_instance_methods_for(klass)`

Returns Array of instance method names for class klass that have been altered by 
MethodProxy.


* `MethodProxy.classes_with_proxied_class_methods`

Returns Array of classes that have at least one class method tapped into by 
MethodProxy.


* `MethodProxy.proxied_class_methods_for(klass)`

Returns Array of class method names for class klass that have been altered by 
MethodProxy.


### EXAMPLES

**Example 1.** Non-intrusive debugging. Here's a way to dynamically "inject" call 
to debugger before an instance method of interest UsersController#create, with 
the help of MethodProxy:

	require 'method_proxy'
	require 'ruby-debug'
	MethodProxy.proxy_instance_method(UsersController, :create) do |users_controller_obj, orig_create_meth, *args|
	  debugger
	  res = orig_create_meth.call *args
	  next res
	end


**Example 1b.** Debug on exception:

    require 'method_proxy'
    require 'ruby-debug'
    MethodProxy.proxy_instance_method(UsersController, :create) do |users_controller_obj, orig_create_meth, *args|
      begin
        res = orig_create_meth.call *args
      rescue Exception => e
        debugger
      end
      next res
    end


**Example 2.** Automatic recording of system actions during QA process. With the help of MethodProxy one can
arrange interception of actions of interest (say, those that change database state), and storing of the
actions' parameters:

	tbd = {
	  UsersController => [:create, :update, :delete],
	  PostsController => [:create, :update, :delete]
	}

	tbd.each_pair do |cntrlr, actns|
	  actns.each do |actn|
	    MethodProxy.proxy_instance_method(cntrlr, actn) do |controller, meth, *args| 
	      record_hash = Hash.new
	      record_hash[:controller] = controller.class.name.to_sym
	      record_hash[:action] = actn
	      record_hash[:http_meth] = controller.request.method
	      record_hash[:params] = controller.request.params
      
	      store_action_record(record_hash)    # store the information - implement according to your needs!
      
	      meth.call *args
	    end
	  end
	end


Later, the resulting "records" can be "replayed" in automated tests.


### CAVEATS

There is a number of known issues:

- currently, method_proxy cannot tap into method calls that accept blocks;
- have to remember to use "next <result>" instead of "return <result>" syntax;
- if one needs to tap into methods that are dynamically created, e.g. 
'find_user_by_id' created on-the-fly with the help of 'method_missing' in 
Rails, the code should make sure that method has been defined before attempting 
to tap.


### RELATION TO AOP 

"Tapping" into method calls the way 'method_proxy' does is similar to creating 
joint points in Aspect-Oriented Programming, and the same task can be 
accomplished with AOP frameworks like Aquarium. 'method_proxy' however is 
intended as a simple tool focused on its task - with no attempt to align it 
with AOP concepts and terminology.


### LICENSE 

Usage, distribution or modification, for both commercial or non-profit purposes, 
are not limited whatsoever.


### DISCLAIMER 

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


### PROJECT ON THE WEB 

The project is hosted on GitHub:
https://github.com/kudelabs/method_proxy/