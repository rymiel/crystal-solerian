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
    'ð' => "ð̠",
  }

  MAKE_STRESSED     = {'a' => 'á', 'e' => 'é', 'i' => 'í', 'o' => 'ó', 'u' => 'ú', 'y' => 'ý'}
  PRESERVE_CLUSTERS = ["ts", "tɕ", "kʲ"]

  def self.set_at_index(str : String, index : Int32, char : Char) : String
    "#{str[...index]}#{char}#{str[(index + 1)..]}"
  end

  def self.lax_stress(word : String) : String
    count_vowels = word.count &.in? VOWEL
    stress_index = word.chars.index &.in? STRESS
    word = word.sub(MAKE_STRESSED) if stress_index.nil? && count_vowels > 1
    word
  end

  def self.syllabify(word : String, *, mark_stress = true) : String
    word = word.gsub(/([#{VOWEL}][^#{VOWEL}]*?)(?=[^#{VOWEL}]?[#{VOWEL}])/, "\\1.")
    PRESERVE_CLUSTERS.each do |cluster|
      word = word.gsub("#{cluster[0]}.#{cluster[1]}", ".#{cluster}")
    end

    count_vowels = word.count &.in? VOWEL
    stress_index = word.chars.index &.in? STRESS
    if stress_index
      stress_boundary = word.rindex('.', stress_index)
    end

    if count_vowels <= 1
      # pass
    elsif stress_boundary.nil?
      word = '\u02c8' + word
    else
      word = self.set_at_index(word, stress_boundary, '\u02c8')
    end
    word = word.sub('\u02c8', '.') unless mark_stress
    word = word.strip('.')
    return word.gsub POST_UNROMANIZE
  end

  def self.single_word_sound_change(word : String, *, mark_stress = true) : String
    word = word.gsub(PRE_UNROMANIZE)
    word = self.lax_stress(word) if mark_stress
    CHANGES.each do |(pattern, replacement)|
      word = word.gsub(pattern, replacement)
    end

    return self.syllabify(word, mark_stress: mark_stress)
  end

  def self.sound_change(phrase : String, *, mark_stress = true) : String
    words = phrase.split(" ").map { |i| single_word_sound_change(i, mark_stress: mark_stress) }

    return "[#{words.join " "}]"
  end
end
