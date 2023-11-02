module Solerian::SoundChange
  VOWEL  = "əaeiouyáéíóúýɔƆæÆɐ"
  CONS   = "fgdtrmnɲsljkxɕcʲh"
  STRESS = "áéíóúýƆÆ"

  CHANGES = [
    {
      /st([eéií])/, "ɕ\\1",
    },
    {
      /([^s]?)t([ií])/, "\\1ts\\2",
    },
    {
      /t([eéií])/, "ç\\1",
    },
    {
      /([kg])y/, "\\1ʲi",
    },
    {
      /([kg])ý/, "\\1ʲí",
    },
    {
      /ox([#{VOWEL}r])/, "a\\1",
    },
    {
      /óx([#{VOWEL}r])/, "á\\1",
    },
    {
      /([#{VOWEL}])x([#{VOWEL}])/, "\\1g\\2",
    },
    {
      /^x/, "h",
    },
    {
      /[əa][əa]/, "ae",
    },
    {
      /[əa]á/, "aé",
    },
    {
      /á[əa]/, "áe",
    },
    {
      /aj/, "ae",
    },
    {
      /ae/, "je",
    },
    {
      /áe/, "é",
    },
    {
      /àé/, "Æ",
    },
    {
      /([fǹgdtrmnsljkxɕcʲh])e([#{VOWEL}])/, "\\1i\\2",
    },
    {
      /ki([#{VOWEL}])/, "ɕ\\1",
    },
    {
      /([#{VOWEL}])ea/, "\\1e",
    },
    {
      /ry/, "ri",
    },
    {
      /rý/, "rí",
    },
    {
      /ra/, "ræ",
    },
    {
      /rá/, "rÆ",
    },
    {
      /([əaeiouy)])\1/, "\\1j\\1",
    },
    {
      /[əa]([#{CONS}]*)([iyíý])/, "e\\1\\2",
    },
    {
      /á([#{CONS}]*)([iyíý])/, "é\\1\\2",
    },
    {
      /u([#{CONS}]*)([iyíý])/, "y\\1\\2",
    },
    {
      /ú([#{CONS}]*)([iyíý])/, "ý\\1\\2",
    },
    {
      /g$/, "ŋ",
    },
    {
      /úu/, "úju",
    },
    {
      /uú/, "ujú",
    },
    {
      /aá/, "ajá",
    },
    {
      /áa/, "ája",
    },
    {
      /ée/, "éje",
    },
    {
      /eé/, "ejé",
    },
    {
      /íi/, "íji",
    },
    {
      /ií/, "ijí",
    },
    {
      /óo/, "ójo",
    },
    {
      /óo/, "ójo",
    },
    {
      /ýy/, "ýjy",
    },
    {
      /yý/, "yjý",
    },
    {
      /əə/, "əjə",
    },
    {
      /əa/, "əja",
    },
    {
      /aə/, "ajə",
    },
    {
      /əá/, "əjá",
    },
    {
      /áə/, "ájə",
    },
    {
      /ld/, "ll",
    },
    {
      /([#{VOWEL}]?)d([#{VOWEL}])/, "\\1ð\\2",
    },
    {
      /[əea]r/, "ɐr",
    },
    {
      /x/, "",
    },
  ]

  PRE_UNROMANIZE = {
    'a' => "ə",
    'à' => "a",
    'ǹ' => "ɲ",
  }

  POST_UNROMANIZE = {
    'á' => "a",
    'é' => "e",
    'í' => "i",
    'ó' => "o",
    'ú' => "u",
    'y' => "ɨ",
    'ý' => "ɨ",
    'ɔ' => "ɑ",
    'Ɔ' => "ɑ",
    'Æ' => "æ",
    'x' => "ɣ",
    'ð' => "ð̠",

    'ʦ' => "ts",
    'ʨ' => "tɕ",
    'q' => "kʲ",
  }

  def self.syllabify(ortho : String, *, mark_stress = true) : String
    total_vowels = 0
    total_schwa = 0
    flag = false
    was_vowel = false
    breaks = [] of Int32
    stress = 0
    syll = String::Builder.new

    ortho.each_char_with_index do |c, i|
      if VOWEL.includes? c
        if flag
          if was_vowel
            breaks.push(i)
          else
            breaks.push(i - 1)
          end
        end

        flag = true
        if STRESS.includes?(c) && breaks.size > 0
          stress = breaks.last
        end

        total_vowels += 1
        total_schwa += 1 if c == 'ə'
        was_vowel = true
      else
        was_vowel = false
      end
    end

    if total_vowels == 1
      stress = -1
    elsif total_vowels - total_schwa == 1
      ortho.each_char_with_index do |c, i|
        if VOWEL.includes?(c) && c != 'ə'
          if i < breaks[0]
            stress = 0
          else
            stress = breaks[0]
          end
        end
      end
    end

    ortho.each_char_with_index do |c, i|
      syll << '.' if breaks.includes?(i)
      syll << '\'' if i == stress && mark_stress
      syll << (POST_UNROMANIZE[c]? || c)
    end

    return syll.to_s
  end

  def self.single_word_sound_change(word : String, *, mark_stress = true) : String
    original_word = word
    word = word.gsub(PRE_UNROMANIZE)
    CHANGES.each do |(pattern, replacement)|
      word = word.gsub(pattern, replacement)
    end
    word = word.gsub("ts", 'ʦ').gsub("tɕ", 'ʨ').gsub("kʲ", "q")
    word = self.syllabify(word, mark_stress: mark_stress)
    return word
  end

  def self.sound_change(phrase : String, *, mark_stress = true) : String
    words = phrase.split(" ").map { |i| single_word_sound_change(i, mark_stress: mark_stress) }

    return "[#{words.join " "}]"
  end
end
