$VERBOSE=1
$Debug=1
require 'test/unit'
require 'set'
require 'ostruct'
require 'yaml'

require 'ron'
#require 'warning'

def try_require name
  require name
rescue Exception
  nil
end

try_require 'rubygems' 
try_require("sequence/weakrefset")
try_require 'facets/more/superstruct' 

require "test/test_graphcopy"

$Verbose=true

=begin
Object
Array
Hash
Struct
:SuperStruct  #
:OpenStruct  
:Set
:SortedSet
:WeakRefSet  
Binding
(Object)
#+self-referencing versions of above

#also need a christmas tree, that incorporates at least one of each
#datum, as many of them as possible self-referencing.
#
#and don't forget repeated data
=end

class A_Class
  def initialize
    @a,@b=1,2
  end
  attr_reader :a,:b
  def ==(other)
    [@a,@b]==[other.a,other.b]
  end
end

class A_Struct < Struct.new(:a,:b)
  def initialize
    self.a=1
    self.b=2
  end
end

class BindingMaker
def get_a_binding
  a=12
  binding
end
def == bm
  BindingMaker===bm
end
end

class MyString<String
  attr_accessor :ivar
end

class MyRegexp<Regexp
  attr_accessor :ivar
end

class MyArray<Array
  attr_accessor :ivar
end

class MyHash<Hash
  attr_accessor :ivar
end

class MyRange<Range
  attr_accessor :ivar
end

module M
end

unless Dir.new('.')==Dir.new('.')
  class Dir
    def ==(other)
      self.class==other.class and path==other.path and pos==other.pos
    end
  end
end

class RonTest<Test::Unit::TestCase

def test_ron
s1=1.0
s2=2.0
range=s1..s2
s1.instance_variable_set(:@m, range)
s2.instance_variable_set(:@m, range)
ss=Set[s1,s2]
s1.instance_variable_set(:@n, ss)
s2.instance_variable_set(:@n, ss)

s1=1.0
s2=2.0
sss=SortedSet[s1,s2]
s1.instance_variable_set(:@o, sss)
s2.instance_variable_set(:@o, sss)

 sss.inspect  #disable this and tests fail...  why?!?!?
strongrefs=%w[a b c]
data=[
 34565.23458888888*0.5,
 45245.765735422567*0.5,
 3.14159,
 1.2345678901234567,
 2**2000,

 "string",
 /regexp/,
 Enumerable,
 Class,
 BindingMaker.new.get_a_binding,
 A_Struct.new,
 
   (record = OpenStruct.new
   record.name    = "John Smith"
   record.age     = 70
   record.pension = 300
   record),

 SortedSet[1,2,3],
 1..10,

 [1,2,3],
 {1=>2,3=>4},
 Set[1,2,3],
 (Sequence::WeakRefSet[*strongrefs] rescue warn 'weakrefset test disabled'),
 A_Class.new,
 2,
 :symbol,
 nil,
 true,
 false,
 
 MyString.new,
 MyRegexp.new(//),
 MyArray.new,
 MyHash.new,
 MyRange.new(1,2),

 "\\",
 "'", 
 Time.now,
 Date.new,
 #File::Stat.new('.'), #maybe someday...
]
data.each{|datum|
  GC.disable
  #p datum
  assert_equal datum, datum
  assert_equal datum, ( dup=eval datum.to_ron )
  assert_equal internal_state(datum), internal_state(dup)
 
  if case datum
     when Fixnum,Symbol,true,false,nil; false
     else true
     end
  datum.instance_eval{@a,@b=1,2}
  assert_equal datum, ( dup=eval datum.to_ron )
  assert_equal internal_state(datum), internal_state(dup)

  datum.instance_eval{@c=self}
  assert_equal datum, ( dup=eval datum.to_ron )
  assert_equal internal_state(datum), internal_state(dup)

  datum.extend(M)
  assert_equal datum, ( dup=eval datum.to_ron )
  assert_equal internal_state(datum), internal_state(dup)  
  assert M===dup
  end
  GC.enable
}
data.each{|datum|
  GC.disable
  if case datum
     when Fixnum,Symbol,true,false,nil; false
     else true
     end
  datum.instance_eval{@d=data}
  assert_equal datum, ( dup=eval datum.to_ron )
  assert_equal internal_state(datum), internal_state(dup)
  
  datum.extend(M)
  assert_equal datum, ( dup=eval datum.to_ron )
  assert_equal internal_state(datum), internal_state(dup)
  assert M===dup
  end
  GC.enable
}

data2=[
 range,
 sss,
 (a=[];a<<a;a),
 (a=[];a<<a;a<<a;a),
 (h={};h[0]=h;h),
 (h={};h[h]=0;h),
 (h={};h[h]=h;h),
 (s=Set[];s<<s;s),
 (o=MyString.new; o.ivar=o; o),
 (o=MyArray.new; o.ivar=o; o),
 (o=MyHash.new; o.ivar=o; o),
 (o=MyArray.new; o<<o),
 (o=MyHash.new; o[1]=o; o),
 (o=MyRange.new(1,2); o.ivar=o; o),
]
  data2.each{|datum|
  GC.disable
  #p datum
  assert_equal datum.to_yaml, datum.to_yaml
  dup=eval datum.to_ron
  dup.inspect #shouldn't be needed
  assert_equal datum.to_yaml, dup.to_yaml
  assert_equal internal_state(datum)[0...2], internal_state(dup)[0...2]
  assert_equal internal_state(datum)[2..-1].to_yaml, internal_state(dup)[2..-1].to_yaml
 
  if case datum
     when Fixnum,Symbol,true,false,nil; false
     else true
     end
  datum.instance_eval{@a,@b=1,2}
  dup=eval datum.to_ron
  dup.inspect #shouldn't be needed
  assert_equal datum.to_yaml,  dup.to_yaml
  assert_equal internal_state(datum)[0...2], internal_state(dup)[0...2]
  assert_equal internal_state(datum)[2..-1].to_yaml, internal_state(dup)[2..-1].to_yaml

  datum.instance_eval{@c=self}
  dup=eval datum.to_ron
  dup.inspect #shouldn't be needed
  assert_equal datum.to_yaml, dup.to_yaml
  assert_equal internal_state(datum)[0...2], internal_state(dup)[0...2]
  assert_equal internal_state(datum)[2..-1].to_yaml, internal_state(dup)[2..-1].to_yaml

  datum.extend(M)
  dup=eval datum.to_ron
  dup.inspect #shouldn't be needed
  assert_equal datum.to_yaml, dup.to_yaml
  assert_equal internal_state(datum)[0...2], internal_state(dup)[0...2]
  assert_equal internal_state(datum)[2..-1].to_yaml, internal_state(dup)[2..-1].to_yaml  
  assert M===dup
  end
  GC.enable
  }
  GC.disable
  datum= ((w=Sequence::WeakRefSet[];w<<w;w) rescue warn 'weakrefset test disabled')
  assert_equal datum.inspect, datum.inspect
  assert_equal datum.inspect, ( dup=eval datum.to_ron ).inspect
  assert_equal internal_state(datum).inspect, internal_state(dup).inspect
 
  datum.instance_eval{@a,@b=1,2}
  assert_equal datum.inspect, ( dup=eval datum.to_ron ).inspect
  assert_equal internal_state(datum).inspect, internal_state(dup).inspect

  datum.instance_eval{@c=self}
  assert_equal datum.inspect, ( dup=eval datum.to_ron ).inspect
  assert_equal internal_state(datum).inspect, internal_state(dup).inspect

  datum= (o=MyRegexp.new(//); o.ivar=o; o)
  ron=datum.to_ron
  assert_match %r"Recursive\(v\d+_=\{\}, MyRegexp\.new\(\"\"\)\.with_ivars\(:@ivar=>v\d+_\)\)", ron
  assert_equal datum,eval(ron)
  datum.extend M
  ron=datum.to_ron
  assert M===eval(ron)
  GC.enable
end

def nonrecursive_ancestors_of x
  class<<x;ancestors end-[Recursive]
rescue TypeError
  []
end

def internal_state x
  list=(x.instance_variables.map!{|iv| iv.to_s}-::Ron::IGNORED_INSTANCE_VARIABLES[x.class.name]).sort
  [x.class,nonrecursive_ancestors_of(x),list]+list.map{|iv| x.instance_variable_get(iv)}
end

end

class Binding
  def ==(other)
    Binding===other or return
    to_h==other.to_h
  end
end
