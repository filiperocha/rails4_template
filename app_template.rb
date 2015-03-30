# アプリ名の取得
@app_name = app_name

# clean file
run 'rm README.rdoc'

# .gitignore by gibo `brew install gibo`
run 'gibo OSX Ruby Rails JetBrains SASS > .gitignore' rescue nil
gsub_file '.gitignore', /^config\/initializers\/secret_token.rb$/, ''
gsub_file '.gitignore', /config\/secret.yml/, ''

# add to Gemfile
append_file 'Gemfile', <<-CODE

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# CSS Support
gem 'sass-rails'

# Form Builders
gem 'simple_form'

# Process Management
gem 'foreman'

# Pagenation
gem 'kaminari'

# NewRelic
gem 'newrelic_rpm'

# Presenter Layer Helper
gem 'active_decorator'

group :development do
  # N+1問題の検出
  gem 'bullet'
end

group :development, :test do
  # Pry & extensions
  gem 'pry-rails'
  gem 'pry-coolline'
  gem 'pry-byebug'
  gem 'rb-readline'

  # PryでのSQLの結果を綺麗に表示
  gem 'hirb'
  gem 'hirb-unicode'

  # pryの色付けをしてくれる
  gem 'awesome_print'

  # Rspec
  gem 'rspec-rails'

  # test fixture
  gem 'factory_girl_rails'

  # テスト環境のテーブルをきれいにする
  gem 'database_rewinder'

  # Time Mock
  gem 'timecop'

  # Deploy
  gem 'capistrano', '~> 3.2.1'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'capistrano-bundler'
end

group :test do
  # HTTP requests用のモックアップを作ってくれる
  gem 'webmock'
  gem 'vcr'
end

group :production, :staging do
  # ログ保存先変更、静的アセット Heroku 向けに調整
  gem 'rails_12factor'
end
CODE

# install gems
run 'bundle install --path vendor/bundle --jobs=4'

# set config/application.rb
application  do
  %q{
    # Set timezone
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local

    # 日本語化
    I18n.enforce_available_locales = true
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :ja

    # generatorの設定
    config.generators do |g|
      g.orm :active_record
      g.test_framework  :rspec, :fixture => true
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.view_specs false
      g.controller_specs true
      g.routing_specs false
      g.helper_specs false
      g.request_specs false
      g.assets false
      g.helper false
    end

    # libファイルの自動読み込み
    config.autoload_paths += %W(#{config.root}/lib)
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
  }
end

# For Bullet (N+1 Problem)
insert_into_file 'config/environments/development.rb',%(
  # Bulletの設定
  config.after_initialize do
    Bullet.enable = true # Bulletプラグインを有効
    Bullet.alert = true # JavaScriptでの通知
    Bullet.bullet_logger = true # log/bullet.logへの出力
    Bullet.console = true # ブラウザのコンソールログに記録
    Bullet.rails_logger = true # Railsログに出力
  end
), after: 'config.assets.debug = true'

# set Japanese locale
run 'wget https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/ja.yml -P config/locales/'

# application.js(turbolink setting)
run 'rm -rf app/assets/javascripts/application.js'

# Simple Form
generate 'simple_form:install --bootstrap'

# Capistrano
run 'bundle exec cap install'

# Kaminari config
generate 'kaminari:config'

# Database
run 'rm -rf config/database.yml'
if yes?('Use MySQL?([yes] else PostgreSQL)')
  run 'wget https://raw.github.com/ms2sato/rails4_template/master/config/mysql/database.yml -P config/'
else
  run 'wget https://raw.github.com/ms2sato/rails4_template/master/config/postgresql/database.yml -P config/'
  run "createuser #{@app_name} -s"
end

gsub_file 'config/database.yml', /APPNAME/, @app_name
run 'bundle exec rake RAILS_ENV=development db:create'

# Rspec/Spring/Guard
# ----------------------------------------------------------------
# Rspec
generate 'rspec:install'
run "echo '--color -f d' > .rspec"

insert_into_file 'spec/spec_helper.rb',%(
  config.before :suite do
    DatabaseRewinder.clean_all
  end

  config.after :each do
    DatabaseRewinder.clean
  end

  config.before :all do
    FactoryGirl.reload
    FactoryGirl.factories.clear
    FactoryGirl.sequences.clear
    FactoryGirl.find_definitions
  end

  config.include FactoryGirl::Syntax::Methods

  VCR.configure do |c|
      c.cassette_library_dir = 'spec/vcr'
      c.hook_into :webmock
      c.allow_http_connections_when_no_cassette = true
  end
), after: 'RSpec.configure do |config|'

insert_into_file 'spec/spec_helper.rb', "\nrequire 'factory_girl_rails'", after: "require 'rspec/rails'"
gsub_file 'spec/spec_helper.rb', "require 'rspec/autorun'", ''

# MongoDB
# ----------------------------------------------------------------
use_mongodb = if yes?('Use MongoDB? [yes or ELSE]')
append_file 'Gemfile', <<-CODE
\n# Mongoid
gem 'mongoid', '4.0.0.alpha1'
gem 'bson_ext'
gem 'origin'
gem 'moped'
CODE

run 'bundle install'

generate 'mongoid:config'

append_file 'config/mongoid.yml', <<-CODE
production:
  sessions:
    default:
      uri: <%= ENV['MONGOLAB_URI'] %>
CODE

append_file 'spec/spec_helper.rb', <<-CODE
require 'rails/mongoid'
CODE

insert_into_file 'spec/spec_helper.rb',%(
  # Clean/Reset Mongoid DB prior to running each test.
  config.before(:each) do
    Mongoid::Sessions.default.collections.select {|c| c.name !~ /system/ }.each(&:drop)
  end
), after: 'RSpec.configure do |config|'
end

# Redis
# ----------------------------------------------------------------
use_redis = if yes?('Use Redis? [yes or ELSE]')
append_file 'Gemfile', <<-CODE
\n# Redis
gem 'redis'
gem 'redis-store'
gem 'redis-rails'
CODE

run 'bundle install'

run 'wget https://raw.github.com/ms2sato/rails4_template/master/config/initializers/session_store.rb -P config/initializers/'
end

# git init
# ----------------------------------------------------------------
git :init
git :add => '.'
git :commit => "-a -m 'first commit'"

# heroku deploy
# ----------------------------------------------------------------
if yes?('Use Heroku? [yes or ELSE]')
  def heroku(cmd, arguments="")
    run "heroku #{cmd} #{arguments}"
  end

  # herokuに不要なファイルを設定
  file '.slugignore', <<-EOS.gsub(/^  /, '')
  *.psd
  *.pdf
  test
  spec
  features
  doc
  docs
  EOS

  git :add => '.'
  git :commit => "-a -m 'Configuration for heroku'"

  heroku_app_name = @app_name.gsub('_', '-')
  heroku :create, "#{heroku_app_name}"

  # config
  run 'heroku config:set SECRET_KEY_BASE=`rake secret`'
  run 'heroku config:add TZ=Asia/Tokyo'

  # addons
  heroku :'addons:add', 'logentries'
  heroku :'addons:add', 'scheduler'
  heroku :'addons:add', 'mongolab' if use_mongodb
  heroku :'addons:add', 'redistogo' if use_redis

  git :push => 'heroku master'
  heroku :run, "rake db:migrate --app #{heroku_app_name}"

  # scale worker
  if use_heroku_worker
    heroku 'scale web=0'
    heroku 'scale worker=1'
  end

  # newrelic
  if yes?('Use newrelic?[yes or ELSE]')
    heroku :'addons:add', 'newrelic'
    heroku :'addons:open', 'newrelic'
    run 'wget https://raw.github.com/ms2sato/rails4_template/master/config/newrelic.yml -P config/'
    gsub_file 'config/newrelic.yml', /%APP_NAME/, @app_name
    key_value = ask('Newrelic licence key value?')
    gsub_file 'config/newrelic.yml', /%KEY_VALUE/, key_value
  end
end
