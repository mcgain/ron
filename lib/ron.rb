# Copyright (C) 2009  Caleb Clausen
# Distributed under the terms of Ruby's license.

#require 'warning'
require 'ron/graphedge'
require 'continuation' unless defined? Continuation
require 'ron/float_accurate_to_s'

#to_ron

class Object
  #forward decls
  def to_ron; end
  def to_ron_list(x=nil); end
end

module Ron
  class NotSerializeableError<RuntimeError; end
  class NotYetSerializeableError<NotSerializeableError; end
  class NotYetMaybeNeverSerializeableError<NotSerializeableError; end
  
  class Session
    def initialize
      @objects_seen={} #hash of object id to reference to string in output
      @objects_in_progress=[]
      #@output=[] #array of strings of data to be output
    end    
    attr_reader :objects_in_progress, :objects_seen
  end  
  IGNORED_INSTANCE_VARIABLES=Hash.new{[]}
  DefaultMarker={}.freeze

  @@local_names_generated=0
  def Ron.gen_local_name
    "v#{@@local_names_generated+=1}_"
  end  

  def self.dump obj
    obj.to_ron
  end

  def self.load str
    eval str
  end

  def self.extension_modules_of(obj)
    ancs=class<<obj; ancestors end
    ancs=ancs[0...ancs.index(obj.class)]
    return ancs
  rescue TypeError
    return []
  end
  
=begin  
  def self.recurse_safe_objects_equal?(o1,o2,session={})
    pair=[o1.__id__,o2.__id__]
    return true if session[pair]
    session[pair]=1
  
    o1.class==o2.class and
      case o1
      when Array 
        o1.size==o2.size and
        o1.each_with_index{|i1,idx|
          recurse_safe_objects_equal?(i1,o2[idx],session) or return
        }
      
      when Hash
        #oops, this depends on #== and #hash working right for recursive structures, which they don't.
        o1.size==o2.size or return      
        recurse_safe_objects_equal? o1.default,o2.default,session or return
        o1.each_with_index{|(idx,i1),bogus|
          return unless (o2.key? idx and recurse_safe_objects_equal? i1, o2[idx],session)
        }

      when Range
        o1.exclude_end?()==o2.exclude_end?() and
        recurse_safe_objects_equal? o1.begin, o2.begin,session and 
        recurse_safe_objects_equal? o1.end, o2.end,session 

      when Struct
        (mems=o1.members).size==o2.members.size and 
        mems.each{|i|
          recurse_safe_objects_equal? o1[i], (o2[i] rescue return),session or return
        }
      when Binding
        recurse_safe_objects_equal? o1.to_h, o2.to_h, session
      when Proc,Integer,Float,String
        o1==o2
      when Thread,ThreadGroup,Process,IO,Symbol,
           Continuation,Class,Module
             return o1.equal?(o2)
      when Exception
        o1.message==o2.message
      when MatchData 
        o1.to_a==o2.to_a
      when Time
        o1.eql? o2
      else true
      end and
      (iv1=o1.instance_variables).size==o2.instance_variables.size and
      iv1.each{|name| 
        recurse_safe_objects_equal? \
          o1.instance_variable_get(name), 
          (o2.instance_variable_get(name) rescue return),session or return
      } 
  end
=end
end

SR=Ron::DefaultMarker
#Recursive([SR]) #recursive array
#Recursive({SR=>SR}) #doubly recursive hash
#Recursive(Set[SR]) #recursive Set

module Recursive; end
SelfReferencing=Recursive        #old name alias
SelfReferential=SelfReferencing  #old name alias

def Recursive *args #marker='foo',data
    marker,data=*case args.size
    when 2; args
    when 1; [::Ron::DefaultMarker,args.last]
    else raise ArgumentError
    end

    ::Ron::GraphWalk.graphwalk(data){|cntr,o,i,ty|
      if o.equal? marker 
        ty.new(cntr,i,1){data}.replace
        data.extend Recursive
      end
    }  
    data
end
def SelfReferencing #old name alias
  Recursive(v=Object.new, yield(v))
end
alias SelfReferential SelfReferencing  #old name alias
def Ron.Recursive(*args); super end

class Object
  def with_ivars(hash)
    hash.each_pair{|k,v|
      instance_variable_set(k,v)
    }
    self
  end
end

[Fixnum,NilClass,FalseClass,TrueClass,Symbol].each{|k| 
  k.class_eval{ alias to_ron inspect; undef to_ron_list }
}

class Bignum
  def to_ron_list(session) [inspect] end
end

class Float
  def to_ron_list(session) 
    [accurate_to_s]
  end
end

class String
    def to_ron_list session
      result= [ "'", gsub(/['\\]/){ '\\'+$&}, "'" ]
      if self.class!=String
        result=[self.class.name, ".new(", result, ")"]
      end
      result
    end
end

class Regexp
    def to_ron_list session
      if self.class==Regexp      
        [ inspect ]
      else
        [self.class.name, ".new(", self.source.inspect, ")"]
      end
    end
end

class Array
  def to_ron_list session
    result=["["] + 
     map{|i| 
          i.to_ron_list2(session)<<', ' 
        }.flatten<<
    "]"
    result.unshift self.class.name unless self.class==Array
    result
  end
end

class Hash
  def to_ron_list session
    if self.class==Hash
      leader="{"
      trailer="}"
      sep="=>"
    else
      leader=self.class.name+"["
      trailer="]"
      sep=","
    end

    [leader]+map{|k,v| 
      Array(k.to_ron_list2(session)).push sep,
          v.to_ron_list2(session)<<', ' 
    }.flatten<<trailer
  end
end

class Object
  undef to_ron, to_ron_list #avoid warnings
  def to_ron
    #warning "additional modules not handled"
      #warning "prettified output not supported"
    
    to_ron_list2.join
  end
  
  def to_ron_list session
    self.class.name or raise NotSerializableError
    [self.class.name,"-{",
      *instance_variables.map{|ivar| 
        [ivar.to_ron,"=>",
          instance_variable_get(ivar).to_ron_list2(session),', ']
      }.flatten<<
    "}#end object literal"]
    #end
  end
  
  def to_ron_list2(session=Ron::Session.new)
    respond_to? :to_ron_list or return [to_ron]
    if pair=(session.objects_in_progress.assoc __id__)
      str=pair[1]
      if str[/^Recursive\(/]
        result=pair.last #put var name already generated into result
      else
        pair.push result=Ron.gen_local_name
        str[0,0]="Recursive(#{result}={}, "
      end
      result=[result]
    elsif pair=session.objects_seen[ __id__ ]
      str=pair.first
      if str[/^[a-z_0-9]+=[^=]/i] 
        result=pair.last #put var name already generated into result
      else
        pair.push result=Ron.gen_local_name
        str[0,0]=result+"="
      end
      result=[result]
    else
      str=''
      session.objects_in_progress.push [__id__,str]
      result=to_ron_list(session).unshift str
      if result.last=="}#end object literal" 
        result.last.replace "}"
        was_obj_syntax=true
      else
        #append instance_eval
        ivars=instance_variables
        ivars.map!{|iv| iv.to_s } if Symbol===ivars.first
        ivars-=::Ron::IGNORED_INSTANCE_VARIABLES[self.class.name]
        ivars.empty? or result.push ".with_ivars(", *ivars.map{|iv| 
          [":",iv.to_s,"=>",instance_variable_get(iv).to_ron_list2(session),', ']
        }.flatten[0...-1]<<")"
      end
      extensions=Ron::extension_modules_of(self)
      unless extensions.empty?
        result=["(",result,")"] if was_obj_syntax
        result.push ".extend(",extensions,")"
      end
      result.push ")" if str[/^Recursive\(/]
      session.objects_seen[__id__]=[session.objects_in_progress.pop[1]]
      result
    end
    result
  end
end

class Struct
  def to_ron_list  session
    self.class.name or raise NotSerializableError
    result=[self.class.name,"-{"]+
      members.map{|memb| 
        [memb.to_ron_list2(session) , "=>" , self[memb] , ', ']
      }.flatten<<
    "}"
    result=["(",result,")"].flatten unless instance_variables.empty?
    result
  end
end

class Set
  def to_ron_list session
    [self.class.name,"[",
      map{|i| i.to_ron_list2(session)<<", "},
    "]"
    ].flatten
  end
end
Ron::IGNORED_INSTANCE_VARIABLES["Set"]=%w[@hash]
Ron::IGNORED_INSTANCE_VARIABLES["SortedSet"]=%w[@hash @keys]
Ron::IGNORED_INSTANCE_VARIABLES["Sequence::WeakRefSet"]=%w[@ids]

class Range
  def to_ron_list session
#    result=
           [self.class.name, ".new(",first.to_ron_list2(session), ", ",
                  last.to_ron_list2(session),
                  (", true" if exclude_end?),
            ")"
           ]
#    result.flatten!
#    result
  end
end

class Time
  def to_ron_list session
    [self.class.name, ".at(", to_i.to_s, ",", usec.to_s, ")"]
  end
end

class Module
  def to_ron
    name.empty? and raise ::Ron::NotSerializeableError
    name
  end
  undef to_ron_list
end

class Class
  def to_ron
    name.empty? and raise ::Ron::NotSerializeableError
    name
  end
  undef to_ron_list if methods.include? "to_ron_list"
end

class Binding
  def to_h
    l=Kernel::eval "local_variables", self
    l<<"self"
    h={}
    l.each{|i| h[i.to_sym]=Kernel::eval i, self }
    h[:yield]=Kernel::eval "block_given? and proc{|*a__| #,&b__\n yield(*a__) #,&b__\n}", self
    h
  end
  
  class<<self
  def -(*args)
    h=args.first
    return super unless ::Hash===h
    h=h.dup
    the_self=h.delete :self
    the_block=(h.delete :yield) || nil
    keys=h.keys
    keys.empty? or
    code=keys.map{|k| 
      k.to_s
    }.join(',')+',=*Thread.current[:$__Ron__CaptureCtx]'
    mname="Ron__capture_binding#{Thread.current.object_id}" #unlikely method name
    oldmname=newmname=result=nil

    eval "
           newmname=class<<the_self;
             mname=oldmname='#{mname}'
             im=instance_methods
             im.map!{|sym| sym.to_s} if Symbol===im.first
             mname+='-' while im.include? mname
             alias_method mname, oldmname if im.include? oldmname
             def #{mname}
               #{code}
               binding
             end
             mname
           end
         " 
          Thread.current[:$__Ron__CaptureCtx]= h.values
          result=the_self.send mname, &the_block
          Thread.current[:$__Ron__CaptureCtx]=nil
          class<<the_self;
             self
          end.send(*if newmname==mname
           [:remove_method, mname]
          else
           [:alias_method, mname, oldmname]
          end)
          result
  end
  alias from_h -
  end
  
  def to_ron_list session
    result=to_h.to_ron_list2(session).unshift("Binding-")
    result=["(",result,")"].flatten unless instance_variables.empty?
    result
  end
end





#I might be able to implement these eventually....
[
Proc,
Method,
UnboundMethod,
File::Stat,
#Binding,  #??
].each{|k| 
  k.class_eval do
    def to_ron(x=nil); raise Ron::NotYetSerializeableError end
    alias to_ron_list to_ron
  end
}

#what about unnamed class and module?


#not sure about these:
#and other interthead communication mechanisms, like
eval("["+%w[
Continuation
Thread
ThreadGroup
Mutex
Queue
SizedQueue
RingBuffer
ConditionVariable
Semaphore
CountingSemaphore
Multiwait
].map{|x| "(#{x} if defined? #{x}), "}.join+"]").compact.each{|k|
  k.class_eval do
    def to_ron(x=nil); raise Ron:: NotYetMaybeNeverSerializeableError end
    alias to_ron_list to_ron
  end
}


#not a chance in hell:
[
File,
IO,
Dir,
Process,



].each{|k| 
  k.class_eval do
    def to_ron(x=nil); raise Ron::NotSerializeableError end
    alias to_ron_list to_ron
  end
}

=begin Kernel#self_referencing test case
exp=Reg::const  # or Reg::var
stmt=Reg::const  # or Reg::var

exp=exp.set! -[exp, '+', exp]|-['(', stmt, ')']|Integer
stmt=stmt.set! (-[stmt, ';', stmt]|-[exp, "\n"])-1
    --  or  --
stmt=Recursive(stmt={}, 
  (-[stmt, ';', stmt]|
  -[exp=Recursive(exp={}, 
    -[exp, '+', exp]|
    -['(', stmt, ')']|
    Integer
   ), "\n"])-1
)
=end

#Class#-
class Class
  #construct an instance of a class from the data in hash
  def -(*args)
    hash=args.first
    #name.empty? and huh
    Array===hash and return make( *hash )
    return super unless ::Hash===hash
    allocate.instance_eval{
      hash.each{|(k,v)| 
        if ?@==k.to_s[0] 
          instance_variable_set(k,v) 
        else
          send(k+"=",v)
        end
      }
      return self
    }
  end
end

#Struct#-
class<<Struct
  alias new__no_minus_op new
  def new *args
    result=new__no_minus_op(*args)
    class<<result
  def -(*args)
    hash=args.first
    return super unless ::Hash===hash
    name.empty? and huh
    result=allocate
    hash.each{|(k,v)| result[k]=v }
    result
  end
    end
    result
  end
end
