# Redmine K2 Authentication Source
#
# Copyright (C) 2010 Andrew R Jackson
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Let's have a new class for our ActiveRecord-based connection
# to our alternative authentication database. Remember that we're
# not assuming that the alternative authentication database is on
# the same host (and/or port) as Redmine's database. So its current
# database connection may be of no use to us. ActiveRecord uses class
# variables to store state (yay) like current connections and such; thus,
# dedicated class...
class K2CustomDB_ActiveRecord < ActiveRecord::Base
  PAUSE_RETRIES = 5
  MAX_RETRIES = 50
end

# Subclass AuthSource
class AuthSourceK2 < AuthSource

  # authentication() implementation
  # - Redmine will call this method, passing the login and password entered
  #   on the Sign In form.
  #
  # +login+ : what user entered for their login
  # +password+ : what user entered for their password
  def authenticate(login, password)
    retVal = nil
    unless(login.blank? or password.blank?)
      # Get a connection to the authenticating database.
      # - Don't use ActiveRecord::Base when using establish_connection() to get at
      #   your alternative database (leave Redmine's current connection alone).
      #   Use class you prepped above.
      # - Recall that the values stored in the fields of your auth_sources
      #   record are available as self.fieldName

      # First, get the DB Adapter name and database to use for connecting:
      adapter, dbName = self.base_dn.split(':')

      # Second, try to get a connection, safely dealing with the MySQL<->ActiveRecord
      # failed connection bug that can still arise to this day (regardless of
      # reconnect, oddly).
      retryCount = 0
      begin
        connPool = K2CustomDB_ActiveRecord.establish_connection(
          :adapter  => adapter,
          :mode     => 'dblib',
          :dataserver => self.host,
          :username => self.account,
          :password => self.account_password,
          :database => dbName,
          :reconnect => true
        )
        db = connPool.checkout()
      rescue => err # for me, always due to dead connection; must retry bunch-o-times to get a good one if this happens
        $stderr.puts err.backtrace.join("\n")
        raise
        if(retryCount < K2CustomDB_ActiveRecord::MAX_RETRIES)
          sleep(1) if(retryCount < K2CustomDB_ActiveRecord::PAUSE_RETRIES)
          retryCount += 1
          connPool.disconnect!
          retry # start again at begin
        else # too many retries, serious, reraise error and let it fall through as it normally would in Rails.
          raise
        end
      end

      # Third, query the alternative authentication database for needed info. SQL
      # sufficient, obvious, and doesn't require other setup/LoC. Even more the
      # case if we have our database engine compute our digests (here, the whole
      # username is a salt). SQL also nice if your alt auth database doesn't have
      # AR classes and is not part of a Rails app, etc.
      resultRow = db.select_one(
        "SELECT username, firstName, lastName, email from Users inner join Person on Users.personId = Person.personId " +
        "WHERE passwordHash = '#{db.quote_string(password)}' OR passwordHash = substring(master.dbo.fn_varbintohexstr(HashBytes('sha1', '#{db.quote_string(password)}')), 3, 40)"
      )

      unless(resultRow.nil? or resultRow.empty?)
        user = resultRow[self.attr_login]
        unless(user.nil? or user.empty?)
          # Found a record whose login & password digest matches that computed
          # from Sign Inform parameters. If allowing Redmine to automatically
          # register such accounts in its internal table, return account
          # information to Redmine based on record found.
          retVal =
          {
            :firstname => resultRow[self.attr_firstname],
            :lastname => resultRow[self.attr_lastname],
            :mail => resultRow[self.attr_mail],
            :auth_source_id => self.id
          } if(onthefly_register?)
        end
      end
    end
    # Check connection back into pool.
    connPool.checkin(db)
    return retVal
  end

  def auth_method_name
    "K2"
  end
end

