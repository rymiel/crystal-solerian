require "./db"
require "nanoid"
require "./script"
require "./sound_change"

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

  module Dict
    extend self

    SOLERIAN_ORDER = "aàbcdefghijklmnǹopqrstuvwxyz"
    DESTRESS = {'á' => 'à', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ý' => 'y'}
    def collate_solerian(str : String) : Array(UInt8)
      str.gsub(DESTRESS).delete { |i| !i.in? SOLERIAN_ORDER }.chars.map { |i| SOLERIAN_ORDER.index!(i).to_u8! }
    end

    def expand_entries : Nil
      existing_mapped = {} of String => FullEntry
      raw_entries = RawEntry.order([:extra, :eng]).select

      raw_entries.each_with_index do |raw, i|
        full = FullEntry.new
        full.num = i
        full.eng = raw.eng
        full.sol = raw.sol
        full.hash = raw.hash!
        full.script = Script.multi(raw.sol)
        full.ipa = SoundChange.sound_change(raw.sol)
        full.lusarian = raw.l
        full.extra = raw.extra
        full.link = nil # temporary

        existing_mapped[raw.hash!] = full
      end

      raw_entries.sort_by!(&.eng)
      raw_entries.each_with_index do |raw, i|
        existing_mapped[raw.hash!].eng_num = i
      end

      raw_entries.unstable_sort_by!(&.sol).sort_by! { |i| collate_solerian(i.sol) }
      raw_entries.each_with_index do |raw, i|
        existing_mapped[raw.hash!].sol_num = i
      end

      FullEntry.migrator.drop_and_create
      FullEntry.import existing_mapped.values.to_a
    end

    def get(*, order = :num, lusarian = false)
      return FullEntry.order(order).where(lusarian: lusarian)
    end
  end
end
