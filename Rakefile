# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
end

desc "Run tests"
task default: :test

desc "Compile native extension"
task :compile do
  puts "Compiling extension"

  Dir.chdir("ext/rhex") do
    system("make clean") if File.exist?("Makefile")
    system("ruby extconf.rb")
    system("make")
  end

  puts "Done"
end
