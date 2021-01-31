require "colorize"
require "log"

def shorten(string : String, to : Int)
  string = string.rjust(to)
  string = "…" + string[-to + 1..] if string.size > to
  string
end

module Etor
  LOGGER_COLORS = {
    ::Log::Severity::Fatal => :magenta,
    ::Log::Severity::Error => :red,
    ::Log::Severity::Warn  => :yellow,
    ::Log::Severity::Info  => :blue,
    ::Log::Severity::Debug => :cyan,
    ::Log::Severity::Trace => :dark_gray,
  }

  Log = Log.for(".")

  struct Formatter < ::Log::StaticFormatter
    @@source_width = 8
    @@prelude : Int32 = 4 + # [] and spaces
      @@source_width

    def run
      source = @entry.source
      source = "." if source.empty?
      source = shorten(source, @@source_width)
      source = "[#{source}] "

      color = LOGGER_COLORS[@entry.severity]? || :white

      @io << source.colorize(color).bold

      severe = @entry.severity.fatal? || @entry.severity.error?

      @io << @entry.message.gsub("\n", "\n#{" " * @@prelude}").colorize(severe ? color : :white)
    end
  end
end
