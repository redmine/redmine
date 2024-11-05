#/bin/bash

if [[ ! "$WORKSPACE" = /* ]] ||
   [[ ! "$PATH_TO_PLUGIN" = /* ]] ||
   [[ ! "$PATH_TO_REDMINE" = /* ]];
then
  echo "You should set"\
       " WORKSPACE, PATH_TO_PLUGIN, PATH_TO_REDMINE"\
       " environment variables"
  echo "You set:"\
       "$WORKSPACE"\
       "$PATH_TO_PLUGIN"\
       "$PATH_TO_REDMINE"
  exit 1;
fi

case $REDMINE_VERSION in
  1.4.*)  export PATH_TO_PLUGINS=./vendor/plugins # for redmine < 2.0
          export GENERATE_SECRET=generate_session_store
          export MIGRATE_PLUGINS=db:migrate_plugins
          export REDMINE_TARBALL=https://github.com/edavis10/redmine/archive/$REDMINE_VERSION.tar.gz
          ;;
  2.*)  export PATH_TO_PLUGINS=./plugins # for redmine 2.0
          export GENERATE_SECRET=generate_secret_token
          export MIGRATE_PLUGINS=redmine:plugins:migrate
          export REDMINE_TARBALL=https://github.com/edavis10/redmine/archive/$REDMINE_VERSION.tar.gz
          ;;
  master) export PATH_TO_PLUGINS=./plugins
          export GENERATE_SECRET=generate_secret_token
          export MIGRATE_PLUGINS=redmine:plugins:migrate
          export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
          export REDMINE_GIT_TAG=master
          ;;
  *)      echo "Unsupported platform $REDMINE_VERSION"
          exit 1
          ;;
esac

export BUNDLE_GEMFILE=$PATH_TO_REDMINE/Gemfile

clone_redmine() {
  set -e # exit if clone fails
  rm -rf $PATH_TO_REDMINE
  if [ ! "$VERBOSE" = "yes" ]; then
    QUIET=--quiet
  fi
  if [ -n "${REDMINE_GIT_TAG}" ]; then
    git clone -b $REDMINE_GIT_TAG --depth=100 $QUIET $REDMINE_GIT_REPO $PATH_TO_REDMINE
    cd $PATH_TO_REDMINE
    git checkout $REDMINE_GIT_TAG
  else
    mkdir -p $PATH_TO_REDMINE
    wget $REDMINE_TARBALL -O- | tar -C $PATH_TO_REDMINE -xz --strip=1 --show-transformed -f -
  fi
}

run_tests() {
  # exit if tests fail
  set -e

  cd $PATH_TO_REDMINE

  if [ "$VERBOSE" = "yes" ]; then
    TRACE=--trace
  fi

  script -e -c "bundle exec rake redmine:plugins:test NAME="$PLUGIN $VERBOSE
}

uninstall() {
  set -e # exit if migrate fails
  cd $PATH_TO_REDMINE
  # clean up database
  if [ "$VERBOSE" = "yes" ]; then
    TRACE=--trace
  fi
  bundle exec rake $TRACE $MIGRATE_PLUGINS NAME=$PLUGIN VERSION=0
}

run_install() {
  # exit if install fails
  set -e

  # cd to redmine folder
  cd $PATH_TO_REDMINE

  # create a link to the plugin, but avoid recursive link.
  if [ -L "$PATH_TO_PLUGINS/$PLUGIN" ]; then rm "$PATH_TO_PLUGINS/$PLUGIN"; fi
  ln -s "$PATH_TO_PLUGIN" "$PATH_TO_PLUGINS/$PLUGIN"

  if [ "$VERBOSE" = "yes" ]; then
    export TRACE=--trace
  fi

  cp $PATH_TO_PLUGINS/$PLUGIN/.travis-database.yml config/database.yml

  # install gems
  mkdir -p vendor/bundle
  bundle install --path vendor/bundle

  bundle exec rake db:migrate $TRACE
  bundle exec rake redmine:load_default_data REDMINE_LANG=en $TRACE
  bundle exec rake $GENERATE_SECRET $TRACE
  bundle exec rake $MIGRATE_PLUGINS $TRACE
}

while getopts :irtu opt
do case "$opt" in
  r)  clone_redmine; exit 0;;
  i)  run_install;  exit 0;;
  t)  run_tests $2;  exit 0;;
  u)  uninstall;  exit 0;;
  [?]) echo "i: install; r: clone redmine; t: run tests; u: uninstall";;
  esac
done