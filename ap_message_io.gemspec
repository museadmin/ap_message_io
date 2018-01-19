
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ap_message_io/version'

Gem::Specification.new do |spec|
  spec.name          = 'ap_message_io'
  spec.version       = ApMessageIo::VERSION
  spec.authors       = ['Bradley Atkins']
  spec.email         = ['bradley.atkins@bjss.com']

  spec.summary       = 'A messaging module for the state-machine gem'
  spec.description   = 'A messaging module for the state-machine gem'
  spec.homepage      = 'https://github.com/museadmin/ap-message-io'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org.
  # To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this
  # section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'http://localhost:9292/'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'bundler', '~> 1.16'
  spec.add_runtime_dependency 'eventmachine', '~> 1.2.5'
  spec.add_runtime_dependency 'json', '~> 2.0.4'
  spec.add_runtime_dependency 'minitest', '~> 5.10.1'
  spec.add_runtime_dependency 'net'
  spec.add_runtime_dependency 'rake', '~> 0'
  spec.add_runtime_dependency 'rack', '~> 2.0.0'
  spec.add_runtime_dependency 'sinatra', '~> 2.0.0'
  spec.add_runtime_dependency 'state-machine', '~> 0.1.4'
  spec.add_runtime_dependency 'thin'
  spec.add_runtime_dependency 'yard', '~> 0.9.12'
end
