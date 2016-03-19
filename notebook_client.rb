#!/usr/bin/ruby

require './configuration'
require './client'
require './columnizer'
require './note_view'
require './notes'
require 'tempfile'
require 'json'
require 'optparse'

class NotebookClient < Client
  class ServerError < StandardError
  end

  def initialize(options)
    super(HOSTNAME, PORT)
    @options = options
    @token = nil
    @current_note_index = 0
    @page_size = 10
    @notes = Notes.new
    @columnizer = Columnizer.new
    @note_view = NoteView.new(options)
  end

  def command_reader
    print "> "
    begin
      return STDIN.readline.chomp
    rescue EOFError
      return "quit"
    end
  end

  def command_dispatcher(line)
    if line.length == 0
      command_line = ["next"]
    elsif line =~ /^\s*[0-9]+\s*$/
      command_line = ["goto", line.to_i]
    else
      command_line = line.split(' ')
    end
    command = command_line.first.downcase
    dispatcher_command = "_COMMAND_#{command}".to_sym
    if self.respond_to?(dispatcher_command)
      begin
        self.send(dispatcher_command, command_line)
      rescue ServerError => e
        puts "gosh, something went wrong: #{e.message}"
        puts "please try again or send username to support@google.com"
      end
    else
      puts "unknown command: '#{command}'. 'help' for a list of commands"
    end
  end

  def build_request(command, parameters = {})
    packet = {
      command: command,
      username: @options[:username],
      token: @token
    }.merge(parameters)
    return packet
  end

  def rpc(command, parameters = {})
    packet = build_request(command, parameters)
    encoded_packet = JSON.generate(packet)
    @client.write(encoded_packet + "\n")
    response = JSON.parse(@client.readline.chomp)
    if response['success'] == false
      raise ServerError.new(response['message'])
    end
    if response['token']
      @token = response['token']
    end
    if response['notes']
      @notes.load(response['notes'])
      status
    end
    return response
  end

  def status
    if @notes.empty?
      puts "There are no notes, use 'add' to create one."
    elsif @notes.num_notes == 1
      puts "There is 1 note."
    else
      puts "There are #{@notes.num_notes} notes."
    end
  end

  def start_up
    puts "Welcome to Notebook, #{@options[:username]}."
    response = rpc("hello")
    puts "Use 'help' for assistance."
  end

  COMMANDS = [
    ["?", "", "short list of commands" ],
    [ "help", "", "longer list of commands" ],
    [ "status", "", "note status" ],
    [ "list", "", "show a list of all notes" ],
    [ "next", "", "next note" ],
    [ "previous", "", "previous note" ],
    [ "first", "", "show first note" ],
    [ "last", "", "show last note" ],
    [ "current", "", "show current note" ],
    [ "goto", "INDEX", "show current note" ],
    [ "add", "", "add a note" ],
    [ "delete", "", "delete current note" ],
    [ "edit", "", "edit current note" ],
    [ "search", "TERMS", "search for a note" ],
    [ "quit", "", "quit this program" ],
  ]

  def _COMMAND_help(command)
    puts "Notebook allows you to save and retrieve notes"
    puts @columnizer.columnized(COMMANDS)
  end

  def _COMMAND_?(command)
    puts "commands: " + COMMANDS.map(&:first).join(', ')
  end

  def _COMMAND_list(command)
    if @notes.empty?
      puts "no notes, consider 'add' or use 'help' for a list of commands."
      return
    end
    first_note_index = [@notes.num_notes-1, @current_note_index].min
    last_note_index = [@notes.num_notes-1, @current_note_index+@page_size].min
    notes = (first_note_index..last_note_index).map do |i|
      @note_view.format(@notes.get_note(i), i)
    end
    puts notes.join("\n")
    @current_note_index = last_note_index+1
    if @current_note_index >= @notes.num_notes
      @current_note_index = @notes.num_notes-1
    end
  end

  def _COMMAND_status(command)
    response = rpc("hello")
    unless response['notes']
      status
    end
  end

  def _COMMAND_(command)
    _COMMAND_next(command)
  end

  def _COMMAND_next(command)
    @current_note_index += 1
    _COMMAND_current(command)
  end

  def _COMMAND_previous(command)
    @current_note_index -= 1
    _COMMAND_current(command)
  end

  def _COMMAND_last(command)
    @current_note_index = @notes.num_notes - 1
    _COMMAND_current(command)
  end

  def _COMMAND_first(command)
    @current_note_index = 0
    _COMMAND_current(command)
  end

  def _COMMAND_goto(command)
    if command[1].nil?
      puts "goto requires a number as an argument"
      return
    end
    if @notes.empty?
      puts "you have no notes"
      return
    end
    if command[1] < 1 || command[1] >= @notes.num_notes
      puts "invalid note index: #{command[1]}"
      return
    end
    @current_note_index = command[1] - 1
    _COMMAND_current(command)
  end

  def _COMMAND_current(command)
    if @notes.empty?
      puts "you have no notes"
    else
      if @current_note_index < 0
        @current_note_index = 0
      elsif @current_note_index >= @notes.num_notes
        @current_note_index = @notes.num_notes - 1
      end
      puts @note_view.format(@notes.get_note(@current_note_index), @current_note_index)
    end
  end

  def _COMMAND_add(command)
    puts "type your note, a period on a line by itself ends the note."
    lines = []
    while true
      line = STDIN.readline.chomp
      if line == '.' || line.nil?
        break
      end
      lines << line
    end
    response = rpc("create_note", {'body' => lines.join("\n")})
    @notes.set_note(response['note'])
    @current_note_index = @notes.num_notes - 1
    puts "got it"
  end

  def find_editor
    return ENV['VISUAL'] || ENV['EDITOR'] || "ed"
  end

  def _COMMAND_edit(command)
    if @notes.empty?
      puts "no notes, consider using 'add' to add a note"
      return
    end
    target_index = @current_note_index
    note = @notes.get_note(target_index)
    file = Tempfile.new("notebook_client")
    update = false
    editor = find_editor
    begin
      file.write(note['body'])
      file.flush
      if system("#{editor} #{file.path}")
        update = true
      end
    ensure
      if update
        file.rewind
        body = file.read
        response = rpc("update_note", {'note_uuid' => note['note_uuid'], 'body' => body})
        # XXX may need to reacquire note here... just incase re synced, but I can't think
        # XXX of a case where failure will be a problem.
        if response['success'] == true
          note['body'] = body
          puts "updated!"
        else
          puts "something went wrong... hmmm..."
          puts "error: #{response['message']}"
        end
      else
        puts "something looks amiss -- no changes made"
      end
      file.close
      file.unlink
    end
  end

  def _COMMAND_delete(command)
    if @notes.empty?
      puts "no notes"
      return
    end
    target_index = @current_note_index
    target_uuid = @notes.get_note(target_index)['note_uuid']
    response = rpc("delete_note", {'note_uuid' => target_uuid})
    @notes.delete_note(target_uuid)
  end

  def _COMMAND_search(command)
    search_term = command[1..-1].join(' ')
    if search_term.length == 0
      puts "you need to specify a search term, as: 'search baseball games'"
      return
    end
    
    found = @notes.search(search_term)
    if found.length == 0
      puts "no notes found in search"
    else
      puts "found #{found.length} note#{found.length == 1 ? '' : 's'}"
      notes = found.map do |i|
        @note_view.format(@notes.get_note(i), i)
      end.join("\n")
      puts notes
    end
  end

  def _COMMAND_quit(command)
    puts "thanks for playing."
    exit 0
  end
end

options = {
  username: ENV['EMAIL'] || ENV['USER'] || "anonymous",
  colorize: true
}
OptionParser.new do |opts|
  opts.banner = "Usage: notebook_client.rb [options]"

  opts.on("-u", "--username USERNAME", "login as user name") do |u|
    options[:username] = u
  end
  opts.on("-c", "--[no-]colorize", "colorize output") do |c|
    options[:colorize] = c
  end
end.parse!

puts options.inspect

notebook_client = NotebookClient.new(options)
notebook_client.start_up
notebook_client.serve
