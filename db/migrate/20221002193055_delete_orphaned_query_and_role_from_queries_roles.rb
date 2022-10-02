class DeleteOrphanedQueryAndRoleFromQueriesRoles < ActiveRecord::Migration[6.1]
  def self.up
    queries_roles = "#{Query.table_name_prefix}queries_roles#{Query.table_name_suffix}"
    queries = Query.table_name
    roles = Role.table_name

    ActiveRecord::Base.connection.execute "DELETE FROM #{queries_roles} WHERE query_id NOT IN (SELECT DISTINCT(id) FROM #{queries})"
    ActiveRecord::Base.connection.execute "DELETE FROM #{queries_roles} WHERE role_id NOT IN (SELECT DISTINCT(id) FROM #{roles})"
  end

  def self.down
    # no-op
  end
end
