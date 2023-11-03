module Solerian::SoundChange
  VOWEL  = "əaeiouyáéíóúýæÆɐ"
  STRESS = "áéíóúýƆÆ"

  private V = "[#{VOWEL}]"
  private C = "[^#{VOWEL}]"

  CHANGES = {
    /st([eéií])/          => "ɕ\\1",
    /([^s]?)t([ií])/      => "\\1ts\\2",
    /t([eéií])/           => "ç\\1",
    /([kg])y/             => "\\1ʲi",
    /([kg])ý/             => "\\1ʲí",
    /ox(#{V}|r)/          => "a\\1",
    /óx(#{V}|r)/          => "á\\1",
    /(#{V})x(#{V})/       => "\\1g\\2",
    /^x/                  => "h",
    /[əa][əa]/            => "ae",
    /[əa]á/               => "aé",
    /á[əa]/               => "áe",
    /aj/                  => "ae",
    /ae/                  => "je",
    /áe/                  => "é",
    /àé/                  => "Æ",
    /(#{C})e(#{V})/       => "\\1i\\2",
    /ki(#{V})/            => "ɕ\\1",
    /(#{V})ea/            => "\\1e",
    /ry/                  => "ri",
    /rý/                  => "rí",
    /ra/                  => "ræ",
    /rá/                  => "rÆ",
    /(ú|u)u/              => "\\1j",
    /[əa](#{C}*)([iyíý])/ => "e\\1\\2",
    /á(#{C}*)([iyíý])/    => "é\\1\\2",
    /u(#{C}*)([iyíý])/    => "y\\1\\2",
    /ú(#{C}*)([iyíý])/    => "ý\\1\\2",
    /g$/                  => "ŋ",
    /uú/                  => "ujú",
    /(ə|a|á)(ə|a|á)/      => "\\1j\\2",
    /(é|e)(é|e)/          => "\\1j\\2",
    /(í|i)(í|i)/          => "\\1j\\2",
    /(ó|o)(ó|o)/          => "\\1j\\2",
    /(ý|y)(ý|y)/          => "\\1j\\2",
    /ld/                  => "ll",
    /(#{V}?)d(#{V})/      => "\\1ð\\2",
    /[əea]r/              => "ɐr",
    /x/                   => "",
  }

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
    word = word.gsub(/(#{V}[^#{VOWEL}]*?)(?=[^#{VOWEL}]?#{V})/, "\\1.")
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
