require "granite/adapter/sqlite"
require "nanoid"
require "./script"

module Solerian
  alias JSDictEntry = {num: Int32, eng: String, sol: String, hash: String, extra: String, script: String, ipa: String, l: Bool}

  class Entry < Granite::Base
    connection dict
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

    def fill(e : Entry, num : Int32) : JSDictEntry
      {
        num: num,
        eng: e.eng,
        sol: e.sol,
        hash: e.hash!,
        script: Script.multi(e.sol),
        ipa: e.sol,
        l: e.l,
        extra: e.extra
      }
    end
  end
end