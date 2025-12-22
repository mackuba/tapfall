# frozen_string_literal: true

require_relative "lib/tapfall/version"

Gem::Specification.new do |spec|
  spec.name = "tapfall"
  spec.version = Tapfall::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "A gem for ingesting ATProto repository data from a Tap service (extension of the Skyfall gem)"
  # spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "https://ruby.sdk.blue"

  spec.license = "Zlib"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "bug_tracker_uri"   => "https://tangled.org/mackuba.eu/tapfall/issues",
    "changelog_uri"     => "https://tangled.org/mackuba.eu/tapfall/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://tangled.org/mackuba.eu/tapfall",
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'skyfall', '~> 0.6'
end
