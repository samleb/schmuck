# frozen_string_literal: true

require_relative "lib/schmuck/version"

Gem::Specification.new do |spec|
  spec.name = "schmuck"
  spec.version = Schmuck::VERSION
  spec.authors = ["Samuel Lebeau"]
  spec.email = ["samuel.lebeau@less-software.sh"]

  spec.summary = "Readable paths through nested hashes and arrays, usable as blocks."
  spec.description = <<~DESCRIPTION
    Schmuck adds String#to_proc so that a path like '[data]*([items]*[sku])' can be
    passed as a block to traverse parsed JSON and other nested structures.
  DESCRIPTION
  spec.homepage = "https://github.com/samleb/schmuck"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.require_paths = ["lib"]
end
