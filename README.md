# Rails4 application template

Rails4 Application Template. - [Rails Application Templates — Ruby on Rails Guides](http://guides.rubyonrails.org/rails_application_templates.html)

It's easy to start Rails4 x PosgreSQL/MySQL application.

In addition, you can choose following options;

1) MongoDB<br/>
2) Redis<br/>
3) Heroku Push<br/>

## Reparation

I recommend to install gibo before generating Rails project. - [simonwhitaker/gibo](https://github.com/simonwhitaker/gibo)

(It's not compulsory, maybe...)

    brew install gibo

## Execution command

Execute following command for PostgreSQL:

    rails new test_app --database=postgresql --skip-test-unit --skip-bundle -m https://raw.github.com/ms2sato/rails4_template/master/app_template.rb

Execute following command for MySQL:

    rails new test_app --database=mysql --skip-test-unit --skip-bundle -m https://raw.github.com/ms2sato/rails4_template/master/app_template.rb

Caution: Please don't use '-' in application name.

## Supported versions

- Ruby 2.2.0
- Rails 4.2.0

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
