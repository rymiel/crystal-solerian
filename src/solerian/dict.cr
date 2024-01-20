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
    column link : String? = nil # temporary
  end

  class InflectedEntry < Granite::Base
    connection solhttp
    table infldict

    column num : Int32, primary: true, auto: true

    belongs_to raw_entry : RawEntry, foreign_key: hash : String

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

    def expand_entries : Nil
      timer_start = Time.monotonic

      # TODO: maybe be worried about the memory usage of these three data structures, once word count increases?
      existing_mapped = {} of String => FullEntry
      new_inflected = [] of InflectedEntry
      raw_entries = RawEntry.order([:extra, :eng]).select

      timer_logic_start = Time.monotonic

      raw_entries.each_with_index do |raw, i|
        full = FullEntry.new
        full.num = i + 1
        full.hash = raw.hash!
        full.eng = raw.eng
        full.sol = raw.sol
        full.script = Script.multi(raw.sol)
        full.ipa = SoundChange.sound_change(raw.sol, mark_stress: !raw.extra.starts_with?("NAME"))
        full.lusarian = raw.l
        if raw.extra.starts_with? 'N'
          full.extra = "#{raw.extra}-#{Inflection.determine_type(raw.sol, :noun).try &.class_name}"
        elsif raw.extra.starts_with? 'V'
          full.extra = "#{raw.extra}-#{Inflection.determine_type(raw.sol, :verb).try &.class_name}"
        else
          full.extra = raw.extra
        end
        full.link = nil # temporary

        existing_mapped[raw.hash!] = full
      end

      raw_entries.sort_by!(&.eng)
      raw_entries.each_with_index do |raw, i|
        existing_mapped[raw.hash!].eng_num = i + 1
      end

      raw_entries.unstable_sort_by!(&.sol).sort_by! { |i| collate_solerian(i.sol) }
      raw_entries.each_with_index do |raw, i|
        existing_mapped[raw.hash!].sol_num = i + 1
      end

      timer_full_entry_logic_end = Time.monotonic
      RawEntry.where("hash in (select hash from dict group by sol)").select.each_with_index do |raw, i|
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
          infl.hash = raw.hash!
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
      InflectedEntry.import new_inflected, batch_size: 400 # arbitrary value

      timer_end = Time.monotonic
      Log.notice { "Database expansion total took #{timer_end - timer_start}" }
      Log.notice { "Database expansion logic took #{timer_logic_end - timer_logic_start}" }
      Log.notice { "           of which FullEntry #{timer_full_entry_logic_end - timer_logic_start}" }
      Log.notice { "      of which InflectedEntry #{timer_logic_end - timer_full_entry_logic_end}" }
      Log.notice { "Database expansion DB IO took #{(timer_logic_start - timer_start) + (timer_end - timer_logic_end)}" }
      Log.notice { "FullEntry count: #{existing_mapped.size}; InflectedEntry count: #{new_inflected.size}"}
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
