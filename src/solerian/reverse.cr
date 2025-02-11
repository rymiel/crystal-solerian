require "./inflection"

module Solerian::Inflection::Reverse
  record Node, value : String, reason : Symbol, children : Array(Node) = [] of Node do
    def old? : Bool
      reason.in?(OLD_FORMS_COMBINED) || children.any?(&.old?)
    end

    def trivial? : Bool
      reason.in?(TRIVIAL_FORMS) || children.any?(&.trivial?)
    end
  end

  def self.raw_entry_descriptor(word : String, lusarian : Bool = false) : Array(Node)
    words = FullEntry.where(sol: word, lusarian: lusarian).select
    words.map do |w|
      meaning = w.eng
      meaning_parts = meaning.split(";")
      compact_meaning = meaning_parts[0]
      compact_meaning += "; ..." if meaning_parts.size > 1
      sol_link = %(<a href="#{w.full_link}">#{w.sol}</a>)
      dict_link = %(<a href="/dict##{w.hash}">#{compact_meaning}</a>)
      text = %("#{sol_link}": (#{w.extra}) "#{dict_link}")
      Node.new text, :raw
    end
  end

  def self.reverse_entry_descriptor(word : String, lusarian : Bool = false) : Array(Node)
    entries = InflectedEntry.where(sol: word).select
    entries.map do |entry|
      sym = Part.new(entry.part).form(entry.form)
      Node.new Inflection.inflected_entry_description(entry), sym, raw_entry_descriptor(entry.raw, lusarian)
    end
  end

  def self.nodes_as_list(nodes : Array(Node), io : IO)
    io << "<ul>"
    nodes.each do |node|
      io << "<li>" << node.value
      nodes_as_list(node.children, io)
      io << "</li>"
    end
    io << "</ul>"
  end

  def self.reverse(word : String, include_old : Bool, lusarian : Bool = false) : Array(Node)
    entries = [] of Node
    entries += raw_entry_descriptor(word, lusarian)
    entries += reverse_entry_descriptor(word, lusarian)
    POSS_SUFFIXES.each_with_index do |poss_suffix, poss_idx|
      is_old = POSS_FORMS[poss_idx].in? OLD_FORMS_COMBINED
      if word.ends_with?(poss_suffix)
        next if is_old && !include_old
        chopped = Word.normalize!(word.rchop(poss_suffix))
        message = "\"#{word}\": #{POSS_FORMS[poss_idx].to_s.gsub('_', ' ')} possessive of \"#{chopped}\""
        reverse_children = reverse_entry_descriptor(chopped, lusarian)
        entries << Node.new(message, POSS_FORMS[poss_idx], reverse_children) unless reverse_children.empty?
        raw_children = raw_entry_descriptor(chopped, lusarian)
        entries << Node.new(message, POSS_FORMS[poss_idx], raw_children) unless raw_children.empty?
      end
    end

    entries.reject!(&.old?) unless include_old
    entries.reject!(&.trivial?)

    return entries
  end

  def self.reverse_html(word : String, include_old : Bool) : String?
    nodes = reverse word, include_old

    if nodes.empty?
      return nil
    else
      return String.build { |str| nodes_as_list(nodes, str) }
    end
  end
end
