#!/usr/bin/ruby

require './server'
require './data_hole'

class NotebookServer < Server
  VERSION = "0.8"

  def initialize
    super(HOSTNAME, PORT)
    @data_hole = DataHole.new
  end

  def build_response(request, user, payload = {})
    response = {
      version: VERSION,
      token: user['token'],
    }.merge(payload)
    if request['token'].nil? || request['token'] < user['last_updated_at']
      unless payload.has_key? 'notes'
        results = @data_hole.fetch(request['username'])        
        if results['success']
          response['notes'] = results['notes']
          response['token'] = results['token']
        end
      end
    end
    if response['success'] == false
      puts "sending error to #{request['username']}"
      puts "ERROR MESSAGE: #{response['message']}"
    end
    return response
  end

  def _COMMAND_hello(request)
    username = request['username']
    user = @data_hole.validate_login(username, false) || @data_hole.create_user(username)
    return build_response(request, user)
  end

  def _COMMAND_create_note(request)
    user = @data_hole.validate_login(request['username'])
    results = @data_hole.create_note(request['username'], request['body'])
    if results['success'] == true
      return build_response(request, user, { 'success' => true, 'note' => results['note'], 'token' => results['token'] })
    else
      return build_response(request, user, results)
    end
  end

  def _COMMAND_delete_note(request)
    user = @data_hole.validate_login(request['username'])
    results = @data_hole.delete_note(request['username'], request['note_uuid'])
    if results['success'] == true
      return build_response(request, user, { 'success' => true, 'token' => results['token'] })
    else
      return build_response(request, user, results)
    end
  end

  def _COMMAND_update_note(request)
    user = @data_hole.validate_login(request['username'])
    results = @data_hole.update_note(request['username'], request['note_uuid'], request['body'])
    if results['success'] == true
      return build_response(request, user, { 'success' => true, 'token' => results['token'] })
    else
      return build_response(request, user, results)
    end
  end
end

notebook_server = NotebookServer.new

notebook_server.serve
