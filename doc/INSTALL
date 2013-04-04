== Redmine installation

Redmine - project management software
Copyright (C) 2006-2013  Jean-Philippe Lang
http://www.redmine.org/


== Requirements

* Ruby 1.8.7, 1.9.2, 1.9.3 or 2.0.0
* RubyGems
* Bundler >= 1.0.21

* A database:
  * MySQL (tested with MySQL 5.1)
  * PostgreSQL (tested with PostgreSQL 9.1)
  * SQLite3 (tested with SQLite 3.7)
  * SQLServer (tested with SQLServer 2012)

Optional:
* SCM binaries (e.g. svn, git...), for repository browsing (must be available in PATH)
* ImageMagick (to enable Gantt export to png images)

== Installation

1. Uncompress the program archive

2. Create an empty utf8 encoded database: "redmine" for example

3. Configure the database parameters in config/database.yml
   for the "production" environment (default database is MySQL and ruby1.9)

   If you're running Redmine with MySQL and ruby1.8, replace the adapter name
   with `mysql`

4. Install the required gems by running:
     bundle install --without development test

   If ImageMagick is not installed on your system, you should skip the installation
   of the rmagick gem using:
     bundle install --without development test rmagick

   Only the gems that are needed by the adapters you've specified in your database
   configuration file are actually installed (eg. if your config/database.yml
   uses the 'mysql2' adapter, then only the mysql2 gem will be installed). Don't
   forget to re-run `bundle install` when you change config/database.yml for using
   other database adapters.

   If you need to load some gems that are not required by Redmine core (eg. fcgi),
   you can create a file named Gemfile.local at the root of your redmine directory.
   It will be loaded automatically when running `bundle install`.

5. Generate a session store secret
   
   Redmine stores session data in cookies by default, which requires
   a secret to be generated. Under the application main directory run:
     rake generate_secret_token

6. Create the database structure
   
   Under the application main directory run:
     rake db:migrate RAILS_ENV="production"
   
   It will create all the tables and an administrator account.

7. Setting up permissions (Windows users have to skip this section)
   
   The user who runs Redmine must have write permission on the following
   subdirectories: files, log, tmp & public/plugin_assets.
   
   Assuming you run Redmine with a user named "redmine":
     sudo chown -R redmine:redmine files log tmp public/plugin_assets
     sudo chmod -R 755 files log tmp public/plugin_assets

8. Test the installation by running the WEBrick web server
   
   Under the main application directory run:
     ruby script/rails server -e production
   
   Once WEBrick has started, point your browser to http://localhost:3000/
   You should now see the application welcome page.

9. Use the default administrator account to log in:
   login: admin
   password: admin
   
   Go to "Administration" to load the default configuration data (roles,
   trackers, statuses, workflow) and to adjust the application settings

== SMTP server Configuration

Copy config/configuration.yml.example to config/configuration.yml and
edit this file to adjust your SMTP settings.
Do not forget to restart the application after any change to this file.

Please do not enter your SMTP settings in environment.rb.

== References

* http://www.redmine.org/wiki/redmine/RedmineInstall
* http://www.redmine.org/wiki/redmine/EmailConfiguration
* http://www.redmine.org/wiki/redmine/RedmineSettings
* http://www.redmine.org/wiki/redmine/RedmineRepositories
* http://www.redmine.org/wiki/redmine/RedmineReceivingEmails
* http://www.redmine.org/wiki/redmine/RedmineReminderEmails
* http://www.redmine.org/wiki/redmine/RedmineLDAP
