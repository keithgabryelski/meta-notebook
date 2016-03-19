require 'pg'
require 'uuid'

class Db
  def initialize(dbname)
    @connection = PG::Connection.open(dbname: dbname)
    @uuid_generator = UUID.new
  end

  def get_1(*parameters)
    results = @connection.exec_params(*parameters).to_a
    if results.length != 1
      raise "oops: unexpected number of rows returned"
    end
    return results.first
  end

  def get_0or1(*parameters)
    results = @connection.exec_params(*parameters).to_a
    if results.length > 1
      raise "oops: #{results.length} rows returned when 1 or none expected"
    end
    return results.first
  end

  def get_many(*parameters)
    results = @connection.exec_params(*parameters).to_a
    return results
  end

  def execute(*parameters)
    @connection.exec_params(*parameters)
  end
end
