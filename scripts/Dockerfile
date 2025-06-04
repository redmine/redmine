FROM redmine:latest

# Remove default Redmine installation but keep the mounted files directory
RUN find /usr/src/redmine -mindepth 1 ! -regex '^/usr/src/redmine/files\(/.*\)?' -delete

# Copy local git checkout
COPY .. /usr/src/redmine/
RUN chown -R redmine:redmine /usr/src/redmine

# Temporarily install development packages for rake/gem installation
USER root
RUN apt-get update
RUN apt-get install -y sqlite3 libsqlite3-dev build-essential libffi-dev libgmp-dev libyaml-dev ruby-dev

USER redmine
WORKDIR /usr/src/redmine

# Create a temporary SQLite config for plugin installation
RUN echo "production:" > config/database.yml && \
    echo "  adapter: sqlite3" >> config/database.yml && \
    echo "  database: db/redmine.sqlite3" >> config/database.yml

RUN bundle install
RUN bundle install --with development
RUN bundle exec rake generate_secret_token
RUN RAILS_ENV=production bundle exec rake db:create db:migrate redmine:plugins

USER root
RUN apt-get remove -y sqlite3 libsqlite3-dev build-essential libffi-dev libgmp-dev libyaml-dev ruby-dev
RUN apt-get autoremove -y
RUN apt-get clean

# Clean up temporary files
RUN rm config/database.yml && \
    find db/ -name "*.sqlite3*" -delete && \
    rm -f db/schema.rb

# Copy and set up the custom entrypoint
COPY scripts/entrypoint-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh

USER redmine

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
