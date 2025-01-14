require "./db"
require "nanoid"
require "./script"
require "./sound_change"
require "./inflection"
require "uri"

module Solerian
  module CommonEntry
  end

  class RawEntry < Granite::Base
    include CommonEntry
    connection solhttp
    table dict

    before_save :auto_hash

    column hash : String, primary: true, auto: false
    column eng : String
    column sol : String
    column l : Bool = false
    column extra : String
    timestamps

    def full_entry : FullEntry
      FullEntry.find_by!(hash: self.hash!)
    end

    def auto_hash
      if !@hash
        @hash = Nanoid.generate(size: 10)
      end
    end

    # this is here because i regret naming the field a single character but i also don't want to rename the DB column
    def lusarian : Bool
      @l || false
    end
  end

  class FullEntry < Granite::Base
    connection solhttp
    table fulldict

    column num : Int32, primary: true, auto: false
    column eng_num : Int32
    column sol_num : Int32

    column hash : String

    column eng : String
    column sol : String
    column extra : String
    column extra_hover : String
    column script : String
    column ipa : String
    column lusarian : Bool
    column link : String?

    def full_link : String?
      link = self.link
      return nil if link.nil?
      return "#{link}?s=#{URI.encode_path self.sol}"
    end
  end

  class InflectedEntry < Granite::Base
    connection solhttp
    table infldict

    column num : Int32, primary: true

    column raw : String

    column part : Int32 # Inflection::Part
    column type : Int32 # Inflection::Type
    column form : Int32 # index into Inflection::NOUN_FORMS or Inflection::VERB_FORMS
    column sol : String
    column script : String
    column ipa : String
  end

  class ExceptionEntry < Granite::Base
    include CommonEntry
    connection solhttp
    table exceptdict

    before_save :auto_hash

    column hash : String, primary: true, auto: false
    column eng : String
    column sol : String
    column lusarian : Bool = false
    column extra : String
    column forms : String
    timestamps

    def auto_hash
      if !@hash
        @hash = Nanoid.generate(size: 10)
      end
    end
  end

  module Dict
    extend self

    SOLERIAN_ORDER = "aàbcdefghijklmnǹopqrstuvwxyz"
    DESTRESS       = {'á' => 'à', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ý' => 'y'}

    PARTS_OF_SPEECH = {
      "N"        => "Noun (pattern %)",
      "N+NAME"   => "Name and onomatonym (pattern %)",
      "NAME"     => "Onomatonym (pattern %)",
      "V"        => "Verb (pattern %)",
      "adv."     => "Adverb",
      "affix"    => "Affix",
      "conj."    => "Conjunction",
      "phrase"   => "Phrase",
      "postpos." => "Postposition",
      "pron."    => "Pronoun (pattern %)",
    }

    def get_extra_hover(extra : String) : String
      parts = extra.split('-')
      part_of_speech = parts[0]
      type = parts[1]?

      if abbr = PARTS_OF_SPEECH[part_of_speech]?
        if type
          "<abbr title=\"#{abbr.sub('%', type)}\">#{extra}</abbr>"
        else
          "<abbr title=\"#{abbr}\">#{extra}</abbr>"
        end
      else
        extra
      end
    end

    def collate_solerian(str : String) : Array(UInt8)
      str.gsub(DESTRESS).delete { |i| !i.in? SOLERIAN_ORDER }.chars.map { |i| SOLERIAN_ORDER.index!(i).to_u8! }
    end

    alias MinimalEntry = {hash: String, sol: String, eng: String, extra: String}

    def expand_entries : Nil
      Log.notice { GC.stats.heap_size.humanize_bytes }
      timer_start = Time.monotonic

      # TODO: maybe be worried about the memory usage of these three(!) data structures, once word count increases?
      existing_mapped = {} of String => FullEntry
      new_inflected = [] of InflectedEntry

      minimal_entries = [] of MinimalEntry

      timer_logic_start = Time.monotonic

      build_full = ->(r : CommonEntry) {
        full = FullEntry.new
        full.hash = r.hash!
        full.eng = r.eng
        full.sol = r.sol
        full.script = Script.multi(r.sol)
        full.ipa = SoundChange.sound_change(r.sol, mark_stress: !r.extra.starts_with?("NAME"))
        full.lusarian = r.lusarian
        full.extra = if part = Inflection::Part.from_extra r.extra
                       if r.is_a? ExceptionEntry
                         "#{r.extra}-X"
                       else
                         "#{r.extra}-#{Inflection.determine_type(r.sol, part).try &.pattern_number}"
                       end
                     else
                       r.extra
                     end
        full.link = case Inflection::Part.from_extra r.extra
                    in nil       then nil
                    in .noun?    then "/noun"
                    in .verb?    then "/verb"
                    in .pronoun? then "/pronoun"
                    end
        full.extra_hover = get_extra_hover full.extra

        existing_mapped[r.hash!] = full
        minimal_entries << {hash: r.hash!, sol: r.sol, eng: r.eng, extra: r.extra}
      }
      RawEntry.find_each("", &build_full)
      ExceptionEntry.find_each("", &build_full)

      minimal_entries.sort_by! { |i| {i[:extra], i[:eng]} }
      minimal_entries.each_with_index do |raw, i|
        existing_mapped[raw[:hash]].num = i + 1
      end

      minimal_entries.sort_by!(&.[:eng])
      minimal_entries.each_with_index do |raw, i|
        existing_mapped[raw[:hash]].eng_num = i + 1
      end

      minimal_entries.unstable_sort_by!(&.[:sol]).sort_by! { |i| collate_solerian(i[:sol]) }
      minimal_entries.each_with_index do |raw, i|
        existing_mapped[raw[:hash]].sol_num = i + 1
      end

      timer_full_entry_logic_end = Time.monotonic
      RawEntry.find_each("where hash in (select hash from dict group by sol)") do |raw|
        # XXX: this could techincally be wrong if there are 2 nouns written the same but one being marked for stress
        # and the other one not. I'm not sure if that will ever even happen but it's a possibility.
        mark_stress = !raw.extra.starts_with?("NAME")
        part = Inflection::Part.from_extra raw.extra
        next if part.nil?

        prop = Inflection.determine_prop(raw.sol, part)
        forms = Solerian::Inflection::Word.apply_from(raw.sol, prop, mark_stress: mark_stress)

        forms.each_with_index do |form, form_idx|
          infl = InflectedEntry.new
          infl.raw = raw.sol
          infl.part = part.to_i
          infl.type = prop.type.to_i
          infl.form = form_idx
          infl.sol = form
          infl.script = Script.multi(form)
          infl.ipa = SoundChange.sound_change(form, mark_stress: mark_stress)
          new_inflected << infl
        end
      end

      ExceptionEntry.find_each do |ex|
        part = Inflection::Part.from_extra ex.extra
        next if part.nil?

        forms = ex.forms.split(",")

        forms.each_with_index do |form, form_idx|
          infl = InflectedEntry.new
          infl.raw = ex.sol
          infl.part = part.to_i
          infl.type = Inflection::Type::EX.to_i
          infl.form = form_idx
          infl.sol = form
          infl.script = Script.multi(form)
          infl.ipa = SoundChange.sound_change(form)
          new_inflected << infl
        end
      end
      timer_logic_end = Time.monotonic

      FullEntry.migrator.drop_and_create
      FullEntry.exec "CREATE INDEX full_hash ON fulldict(hash);"
      FullEntry.import existing_mapped.values.to_a, batch_size: 400 # arbitrary value

      InflectedEntry.migrator.drop_and_create
      InflectedEntry.exec "CREATE INDEX infl_part ON infldict(part);"
      InflectedEntry.exec "CREATE INDEX infl_raw ON infldict(raw);"
      InflectedEntry.exec "CREATE INDEX infl_sol ON infldict(sol);"
      InflectedEntry.import new_inflected, batch_size: 400 # arbitrary value

      timer_validation_start = Time.monotonic

      validate_all!

      timer_end = Time.monotonic
      Log.notice { GC.stats.heap_size.humanize_bytes }
      Log.notice { "Database expansion total took #{timer_end - timer_start}" }
      Log.notice { "Database expansion logic took #{timer_logic_end - timer_logic_start}" }
      Log.notice { "           of which FullEntry #{timer_full_entry_logic_end - timer_logic_start}" }
      Log.notice { "      of which InflectedEntry #{timer_logic_end - timer_full_entry_logic_end}" }
      Log.notice { "Database expansion DB IO took #{(timer_logic_start - timer_start) + (timer_validation_start - timer_logic_end)}" }
      Log.notice { "              Validation took #{(timer_end - timer_validation_start)}" }
      Log.notice { "FullEntry count     : #{existing_mapped.size}" }
      Log.notice { "InflectedEntry count: #{new_inflected.size}" }
      Log.notice { "       of which nouns #{InflectedEntry.where(part: Inflection::Part::Noun.to_i).count}" }
      Log.notice { "       of which verbs #{InflectedEntry.where(part: Inflection::Part::Verb.to_i).count}" }
    end

    ONSET     = /(?<onset>sk|(?:[tdkg](?:[lr]|s)|(?:st|[mftdnrslɲjkgx]))?)/
    NUCLEUS   = /(?<nucleus>[aeiouəɨ])/
    CODA_BODY = /(?:(?:x[lrs])|s[tdkg]|[lr](?:s|[tdkg]|[nm])|[tdkg]s|[nm](?:s|[tdkg])|(?:st|[mftdnrslɲjkgx]))?/
    CODA      = "(?<coda>(?=\\g<onset>\\g<nucleus>|$)|(?:st|[mftdnrslɲjkgx])(?=\\g<onset>\\g<nucleus>|$)|#{CODA_BODY})"
    SYLLABLES = /^(#{ONSET}#{NUCLEUS}#{CODA}(?=\g<onset>|$))+/

    def is_valid?(word : String)
      return true if word.includes?('-') # just allow all suffixes for now
      !word.includes?("aa") && !word.includes?("rr") && SoundChange.ipa_without_sound_change(word).matches?(SYLLABLES, options: Regex::MatchOptions::ANCHORED | Regex::MatchOptions::ENDANCHORED)
    end

    def validate_all!
      RawEntry.all.each do |entry|
        next if entry.extra.includes? "NAME"
        next if entry.sol.includes? '-'
        norm = Inflection::Word.normalize! entry.sol
        next if entry.extra.in?("conj.", "postpos.") && norm.gsub('à', 'a') == entry.sol
        Log.error { "\"#{entry.sol}\" is not normalized (\"#{norm}\")" } unless entry.sol == norm
      end

      FullEntry.all.each do |entry|
        Log.error { "#{SoundChange.ipa_without_sound_change(entry.sol)}: \"#{entry.sol}\" is not a valid word" } unless is_valid? entry.sol
      end

      InflectedEntry.where(part: Inflection::Part::Noun.to_i).each do |entry|
        next if Inflection::Part.new(entry.part).form(entry.form).in? Inflection::OLD_FORMS_COMBINED # ignore old entries
        Log.error { "#{SoundChange.ipa_without_sound_change(entry.sol)}: #{Solerian::Inflection.inflected_entry_description entry} is not a valid word" } unless is_valid? entry.sol
      end

      InflectedEntry.where(part: Inflection::Part::Verb.to_i).each do |entry|
        next if Inflection::Part.new(entry.part).form(entry.form).in? Inflection::OLD_FORMS_COMBINED # ignore old entries
        Log.error { "#{SoundChange.ipa_without_sound_change(entry.sol)}: #{Solerian::Inflection.inflected_entry_description entry} is not a valid word" } unless is_valid? entry.sol
      end
    end

    def get(*, order = :num, lusarian = false)
      d = FullEntry.order(order)
      return d.where(lusarian: lusarian) unless lusarian
      d
    end

    def get_raw(*, lusarian = false)
      d = RawEntry.order(:eng)
      return d.where(l: lusarian) unless lusarian
      d
    end
  end
end
