require "./db"
require "nanoid"
require "./script"
require "./sound_change"
require "./inflection"

module Solerian
  class RawEntry < Granite::Base
    connection solhttp
    table dict

    before_save :auto_hash

    column hash : String, primary: true, auto: false
    column eng : String
    column sol : String
    column l : Bool = false
    column extra : String = ""
    timestamps

    has_one full_entry : FullEntry

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

    belongs_to raw_entry : RawEntry, foreign_key: hash : String

    column eng : String
    column sol : String
    column extra : String
    column script : String
    column ipa : String
    column lusarian : Bool
    column link : String?
  end

  class InflectedEntry < Granite::Base
    connection solhttp
    table infldict

    column num : Int32, primary: true, auto: true

    column raw : String

    column part : Int32 # Inflection::Part
    column type : Int32 # Inflection::Type
    column form : Int32 # index into Inflection::NOUN_FORMS or Inflection::VERB_FORMS
    column sol : String
    column script : String
    column ipa : String
  end

  module Dict
    extend self

    SOLERIAN_ORDER = "aàbcdefghijklmnǹopqrstuvwxyz"
    DESTRESS       = {'á' => 'à', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ý' => 'y'}

    def collate_solerian(str : String) : Array(UInt8)
      str.gsub(DESTRESS).delete { |i| !i.in? SOLERIAN_ORDER }.chars.map { |i| SOLERIAN_ORDER.index!(i).to_u8! }
    end

    alias MinimalEntry = { hash: String, sol: String, eng: String }

    def expand_entries : Nil
      Log.notice { GC.stats.heap_size.humanize_bytes }
      timer_start = Time.monotonic

      # TODO: maybe be worried about the memory usage of these three(!) data structures, once word count increases?
      existing_mapped = {} of String => FullEntry
      new_inflected = [] of InflectedEntry

      minimal_entries = [] of MinimalEntry

      timer_logic_start = Time.monotonic

      raw_i = 0
      RawEntry.find_each("ORDER BY extra ASC, eng ASC") do |raw|
        full = FullEntry.new
        full.num = raw_i + 1
        full.hash = raw.hash!
        full.eng = raw.eng
        full.sol = raw.sol
        full.script = Script.multi(raw.sol)
        full.ipa = SoundChange.sound_change(raw.sol, mark_stress: !raw.extra.starts_with?("NAME"))
        full.lusarian = raw.l
        full.extra = if raw.extra.starts_with? 'N'
                       "#{raw.extra}-#{Inflection.determine_type(raw.sol, :noun).try &.class_name}"
                     elsif raw.extra.starts_with? 'V'
                       "#{raw.extra}-#{Inflection.determine_type(raw.sol, :verb).try &.class_name}"
                     else
                       raw.extra
                     end
        full.link = if raw.extra.starts_with? 'N'
                      "/noun"
                    elsif raw.extra.starts_with? 'V'
                      "/verb"
                    else
                      raw.extra
                    end

        existing_mapped[raw.hash!] = full
        minimal_entries << {hash: raw.hash!, sol: raw.sol, eng: raw.eng}
        raw_i += 1
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
        if raw.extra.starts_with? 'N'
          part = Inflection::Part::Noun
        elsif raw.extra.starts_with? 'V'
          part = Inflection::Part::Verb
        else
          next
        end

        prop = Inflection.determine_prop(raw.sol, part)
        next unless prop
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

    MONSTER_REGEX = /^((?<onset>sk|(?:[tdkg](?:[lr]|s)|(?:st|[mftdnrslɲjkgx]))?j?)(?<nucleus>[aeiouəɨ])(?<coda>(?:(?:x[lrs])|s[tdkg]|[lr](?:s|[lr]|[tdkg]|[nm])|[tdkg](?:s|[lr])|[nm](?:s|[lr]|[tdkg])|(?:st|[mftdnrslɲjkgx]))?)(?=\g<onset>|$))+/

    def is_valid?(word : String)
      return true if word.includes?('-') # just allow all suffixes for now
      !word.includes?("aa") && SoundChange.ipa_without_sound_change(word).matches?(MONSTER_REGEX, options: Regex::MatchOptions::ANCHORED | Regex::MatchOptions::ENDANCHORED)
    end

    def validate_all!
      FullEntry.all.each do |entry|
        Log.error { "#{SoundChange.ipa_without_sound_change(entry.sol)}: \"#{entry.sol}\" is not a valid word" } unless is_valid? entry.sol
      end

      InflectedEntry.where(part: Inflection::Part::Noun.to_i).each do |entry|
        next if Inflection::Part.new(entry.part).form(entry.form).in? Inflection::OLD_FORMS_COMBINED # ignore old entries
        Log.error { "#{SoundChange.ipa_without_sound_change(entry.sol)}: #{Solerian.inflected_entry_description entry} is not a valid word" } unless is_valid? entry.sol
      end

      InflectedEntry.where(part: Inflection::Part::Verb.to_i).each do |entry|
        next if Inflection::Part.new(entry.part).form(entry.form).in? Inflection::OLD_FORMS_COMBINED # ignore old entries
        Log.error { "#{SoundChange.ipa_without_sound_change(entry.sol)}: #{Solerian.inflected_entry_description entry} is not a valid word" } unless is_valid? entry.sol
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
