require 'devtools'

Devtools.init_rake_tasks

task :yardstick => ['metrics:yardstick:measure'] do
  # A convenience task to run a yardstick::measure and then print out
  # the mesurements.
  #
  # Semantically the same as `rake metrics:yardstick:measure ; cat measurements/report.txt`
  File.new('measurements/report.txt').each_line do |line|
    puts line
  end
end
