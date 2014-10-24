#!/bin/sh

#set -e
# Install Redmine dependencies
# root need
#aptitude update
#aptitude install sudo curl git
#aptitude install librmagick-ruby libmagick-dev libmagickwand-dev rubygems
#aptitude install nginx postgresql postgresql-server-dev-all
#
## Specify project name
PROJECT='pirati-redmine'
PROJECTRUBY='2.0.0'
#
## Create deployment user - this doesn't necesserily means that you will run
## under this user. You can change your project settings for your rails app
## later. Deployer user can be different than app user.
#PROJECTUSER='deployer'
#adduser --group sudo $PROJECTUSER
#
##install RVM not system wide, but only in users home

curl -L https://get.rvm.io | bash -s stable --auto-dotfiles

echo "$HOME/.rvm/scripts/rvm"

# Load RVM into a shell session *as a function*
if [[ -s "$HOME/.rvm/scripts/rvm" ]] ; then

  # First try to load from a user install
  source "$HOME/.rvm/scripts/rvm"

elif [[ -s "/usr/local/rvm/scripts/rvm" ]] ; then

  # Then try to load from a root install
  source "/usr/local/rvm/scripts/rvm"

else

  printf "ERROR: An RVM installation was not found.\n"

fi

rvm list known

#for Redmine
echo "Installing redmine env"
rvm install $PROJECTRUBY
rvm alias create default $PROJECTRUBY
rvm use $PROJECTRUBY

rvm gemset use default

# use gemset redmine
gem install rmagick ruby-openid unicorn bundle

rvm gemset create $PROJECT
rvm use $PROJECTRUBY@$PROJECT

echo "Your env is ready, run deploy"



## Install the database packages
#sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev
#
## Login to MySQL
#mysql -u root -p
#
## Create a user for Redmine. (change $password to a real password)
#mysql> CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$password';
#
## Create the Redmine production database
#mysql> CREATE DATABASE IF NOT EXISTS `redmine_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;
#
## Grant the Redmine user necessary permissions on the table.
#mysql> GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `redmine_production`.* TO 'redmine'@'localhost';
#
## Quit the database session
#mysql> \q
#
## Try connecting to the new database with the new user
#sudo -u redmine -H mysql -u redmine -p -D redmine_production
#