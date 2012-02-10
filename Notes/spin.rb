spinner = %w{/ - \\ |}


puts
print "Spinning: "
loop do
  spin = spinner.pop
  print "\b" + spin
  spinner.unshift spin
end
