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

    def expand_entries
      full_entries = [] of FullEntry
      i = 1
      RawEntry.order([:extra, :eng]).each do |raw|
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

        full_entries << full
        i += 1
      end

      FullEntry.migrator.drop_and_create
      FullEntry.import full_entries
    end

    def get(*, lusarian = false)
      d = FullEntry.order(:num)
      return d.where(lusarian: lusarian) unless lusarian
      d
    end
  end
end
