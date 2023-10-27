require "./db"
require "nanoid"
require "./script"
require "./sound_change"

module Solerian
  alias FullDictEntry = {num: Int32, eng: String, sol: String, hash: String, extra: String, script: String, ipa: String, l: Bool, link: String?}

  class Entry < Granite::Base
    connection solhttp
    table dict

    before_save :auto_hash

    column hash : String, primary: true, auto: false
    column eng : String
    column sol : String
    column l : Bool = false
    column extra : String = ""
    timestamps

    def auto_hash
      if !@hash
        @hash = Nanoid.generate(size: 10)
      end
    end
  end

  module Dict
    extend self

    def get(*, lusarian = false)
      d = Entry.order([:extra, :eng])
      return d.where(l: lusarian) unless lusarian
      d
    end

    def fill(e : Entry, num : Int32) : FullDictEntry
      {
        num:    num,
        eng:    e.eng,
        sol:    e.sol,
        hash:   e.hash!,
        script: Script.multi(e.sol),
        ipa:    SoundChange.sound_change(e.sol),
        l:      e.l,
        extra:  e.extra,
        link:   nil, # temporary
      }
    end
  end
end
