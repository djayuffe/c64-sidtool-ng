lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sidtool/version"

Gem::Specification.new do |spec|
  spec.name          = 'sidtool'
  spec.version       = Sidtool::VERSION
  spec.authors       = ['Ole Friis Østergaard']
  spec.email         = ['olefriis@gmail.com']

  spec.summary       = 'Convert Commodore 64 PSID tunes to Ruby, MIDI, and SID register traces'
  spec.homepage      = 'https://github.com/djayuffe/c64-sidtool-ng'
  spec.license       = 'MIT'
  spec.metadata      = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  spec.required_ruby_version = '>= 2.3'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = 'sidtool'
  spec.require_paths = ['lib']

  # 0.1.3 removes the obsolete mini_racer/V8 native dependency, which cannot
  # build reliably on current macOS hosts.
  spec.add_dependency 'mos6510', '~> 0.1.3'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry', '~> 0.12.2'
end
