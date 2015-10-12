source 'https://rubygems.org'

group(:development, :test) do
  gem "rspec", '~> 3.3.0'

  # json-schema uses multi_json, but chokes with multi_json 1.7.9, so prefer 1.7.7
  gem "multi_json", "1.7.7", :require => false, :platforms => [:ruby, :jruby]
  gem "json-schema", "2.1.1", :require => false, :platforms => [:ruby, :jruby]
end
