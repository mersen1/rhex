# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "rhex"
  s.version     = "3.3.1"
  s.summary     = "Ruby Hexagonal Grids"
  s.description = <<-DESCRIPTION
    A library providing hexagons management and hexagonal grids for ruby.
    Misc methods (surrounding hexes, nearest hex, distance between hexes).
  DESCRIPTION
  s.authors     = ["Sergey Kucherov"]
  s.files       = Dir["lib/**/*.rb", "fonts/**/*", "README.md", "LICENSE"]
  s.homepage    = "https://github.com/mersen1/rhex"
  s.license     = "MIT"
  s.required_ruby_version = ">= 3.3.7"

  s.add_dependency("activesupport")
  s.add_dependency("dry-validation")
  s.add_dependency("ffi")
  s.add_dependency("rgl")
  s.add_dependency("rmagick")
  s.add_dependency("zeitwerk", "~>2.6")

  s.add_development_dependency("benchmark-ips")
  s.add_development_dependency("pry-byebug")
  s.add_development_dependency("racc")
  s.add_development_dependency("rspec")
  s.add_development_dependency("rubocop")
  s.add_development_dependency("rubocop-shopify")
  s.add_development_dependency("simplecov")
  s.metadata["rubygems_mfa_required"] = "true"
end
