require 'time'

class NoteView
  def initialize(options)
    @options = options
  end

  def bold
    @options[:colorize] ? "\033[1m" : ""
  end

  def normal
    @options[:colorize] ? "\033[0m" : ""
  end

  def green
    @options[:colorize] ? "\e[32m" : ""
  end

  def blue
    @options[:colorize] ? "\e[34m" : ""
  end

  def format(note, index)
    return "#{bold}#{index+1}#{normal}: #{green}#{time_format(note['created_at'])}#{normal}\n#{blue}#{note['body']}#{normal}"
  end

  def time_format(da_time)
    Time.parse(da_time).ctime
  end
end
