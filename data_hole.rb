require './configuration'
require './db'
require 'uuid'

class DataHole
  def initialize
    @db = Db.new(DB_NAME)
    @uuid_generator = UUID.new
  end

  def success(params)
    {
      'success' => true
    }.merge(params)
  end

  def error(message, params = {})
    {
      'success' => false,
      'message' => message
    }.merge(params)
  end

  def set_user_updated(username)
    sql = "UPDATE users SET last_updated_at = NOW() WHERE username = $1 RETURNING last_updated_at"
    token = @db.execute(sql, [username]).to_a.first['last_updated_at']
    return token
  end

  def validate_login(username, assert_failed_login = true)
    user = @db.get_0or1("SELECT * FROM users WHERE username = $1", [username])
    if assert_failed_login && user.nil?
      raise "bad login: #{username}"
    end
    return user
  end

  def fetch(username)
    user = validate_login(username)
    sql = <<-SQL
      SELECT
        note_uuid,
        created_at,
        body
      FROM
        notes
      WHERE
        user_id = $1 AND
        deleted = FALSE
      ORDER BY
        created_at asc
    SQL
    params = [user['id']]
    notes = @db.get_many(sql, params)
    return success({
                     'token' => user['last_updated_at'],
                     'notes' => notes
                   })
  end

  def create_user(username)
    begin
      puts "creating new user: #{username}"
      return @db.execute("INSERT INTO users (username) VALUES ($1) returning *", [username]).to_a.first
    rescue Exception => e
      return nil
    end
  end

  def create_note(username, body)
    user = validate_login(username)
    sql = <<-SQL
      INSERT INTO notes
        (created_at, updated_at, user_id, note_uuid, body)
      VALUES
        (now(), NULL, $1, $2, $3)
      RETURNING
        created_at, note_uuid, body
    SQL
    note_uuid = @uuid_generator.generate
    parameters = [user['id'], note_uuid, body]
    begin
      note = @db.execute(sql, parameters).to_a.first
      return success({'note' => note, 'token' => set_user_updated(username)})
    rescue Exception => e
      return error(e.message)
    end
  end

  def delete_note(username, note_uuid)
    user = validate_login(username)
    sql = <<-SQL
      UPDATE notes
        SET
          deleted = TRUE,
          updated_at = NOW()
      WHERE
        user_id = $1 AND
        note_uuid = $2
    SQL
    parameters = [user['id'], note_uuid]
    begin
      @db.execute(sql, parameters)
    rescue Exception => e
      return error(e.message)
    end
    return success('token' => set_user_updated(username))
  end

  def undelete_note(username, note_uuid)
    user = validate_login(username)
    sql = <<-SQL
      UPDATE
        SET
          deleted = FALSE,
          updated_at = NOW()
      WHERE
        user_id = $1 AND
        note_uuid = $2
    SQL
    parameters = [user['id'], note_uuid]
    begin
      @db.execute(sql, parameters)
    rescue Exception => e
      return error(e.message)
    end
    return success('token' => set_user_updated(username))
  end

  def update_note(username, note_uuid, body)
    user = validate_login(username)
    # update current note
    sql = <<-SQL
      UPDATE notes
        SET
          updated_at = NOW(),
          body = $1
      WHERE
        user_id = $2 AND
        note_uuid = $3
    SQL
    parameters = [body, user['id'], note_uuid]
    begin
      @db.execute(sql, parameters)
    rescue Exception => e
      return error(e.message)
    end
    return success('token' => set_user_updated(username))
  end
end
