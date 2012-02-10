require 'benchmark'

Data = ("aaaa".."zzzz").to_a

Benchmark::bmbm do |m|
  m.report("grepped") { Data.grep(/^eg/)}
  m.report("prefixed") { pre = "eg"; Data.find_all{|str| str[0...pre.length] == pre}}

end
