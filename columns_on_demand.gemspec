# -*- encoding: utf-8 -*-
require File.expand_path('../lib/columns_on_demand/version', __FILE__)

spec = Gem::Specification.new do |gem|
  gem.name         = 'columns_on_demand'
  gem.version      = ColumnsOnDemand::VERSION
  gem.summary      = "Lazily loads large columns on demand."
  gem.description  = <<-EOF
Lazily loads large columns on demand.

By default, does this for all TEXT (:text) and BLOB (:binary) columns, but a list
of specific columns to load on demand can be given.

This is useful to reduce the memory taken by Rails when loading a number of records
that have large columns if those particular columns are actually not required most
of the time.  In this situation it can also greatly reduce the database query time
because loading large BLOB/TEXT columns generally means seeking to other database
pages since they are not stored wholly in the record's page itself.

Although this plugin is mainly used for BLOB and TEXT columns, it will actually
work on all types - and is just as useful for large string fields etc.
EOF
  gem.author       = "Will Bryant"
  gem.email        = "will.bryant@gmail.com"
  gem.homepage     = "http://github.com/willbryant/columns_on_demand"
  gem.license      = "MIT"

  gem.executables  = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files        = `git ls-files`.split("\n")
  gem.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_path = "lib"

  gem.add_dependency "activerecord"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "mysql2"
  gem.add_development_dependency "pg"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "byebug"
end
