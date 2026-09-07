$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your wagon's version:
require "hitobito_florist/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  # rubocop:disable Style/SingleSpaceBeforeFirstArg
  s.name = "hitobito_florist"
  s.version = HitobitoFlorist::VERSION
  s.authors = ["Andreas Maierhofer"]
  s.email = ["maierhofer@puzzle.ch"]
  s.homepage = "https://www.florist.ch"
  s.summary = "hitobito for florist.ch"
  s.description = "hitobito for florist.ch"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile"]
  # rubocop:enable Style/SingleSpaceBeforeFirstArg
end
