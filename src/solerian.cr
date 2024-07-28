require "db"
require "sqlite3"
require "json"
require "solhttp"
require "./solerian/*"

module Solerian
  VERSION   = {{ `shards version #{__DIR__}`.chomp.stringify }}
  FOX_IDENT = ENV["FOX_IDENT"]?
  FOX_HREF  = ENV["FOX_HREF"]?
  Log       = ::Log.for self

  def self.noun_table_entry(word : InflectedEntry)
    %(<td><span class="dual"><a href="/poss/?s=#{word.sol}"><i>#{word.sol}</i></a>&ensp;<span class="sol">#{word.script}</span></span><p>#{word.ipa}</p></td>)
  end

  def self.verb_table_entry(word : InflectedEntry)
    %(<td><span class="dual"><i>#{word.sol}</i>&ensp;<span class="sol">#{word.script}</span></span><p>#{word.ipa}</p></td>)
  end

  def self.pronoun_table_entry(word : InflectedEntry)
    %(<td><span class="dual"><i>#{word.sol}</i>&ensp;<span class="sol">#{word.script}</span></span><p>#{word.ipa}</p></td>)
  end

  get "/" do |ctx|
    templ "index"
  end

  get "/login" do |ctx|
    templ "login"
  end

  post "/login" do |ctx|
    next Auth.check_login ctx
  end

  get "/user" do |ctx|
    next unless Auth.assert_auth ctx
    templ "user"
  end

  get "/logout" do |ctx|
    next unless Auth.assert_auth ctx
    ctx.session.destroy
    ctx.redirect "/"
  end

  get "/dict" do |ctx|
    sort = case ctx.params.query["sort"]?
           when "eng" then :eng_num
           when "sol" then :sol_num
           else            :num
           end
    entries = Dict.get order: sort
    templ "dict"
  end

  get "/noun" do |ctx|
    word = ctx.params.query["s"]?.try { |w| HTML.escape w }
    fail = false
    if word
      forms = InflectedEntry
        .where(raw: word, part: Inflection::Part::Noun.to_i)
        .order(:form)
        .select
      if forms.size > 0
        summary = "#{Inflection::Type.new(forms.first.type).long_name(:noun)} #{word}"
        old_summary = "#{Inflection::Type.new(forms.first.type).old_class_long_name} #{word}"
        table = Inflection::NOUN_FORMS.zip(forms).to_h
      else
        fail = true
      end
    end

    templ "noun"
  end

  get "/verb" do |ctx|
    word = ctx.params.query["s"]?.try { |w| HTML.escape w }
    fail = false
    if word
      forms = InflectedEntry
        .where(raw: word, part: Inflection::Part::Verb.to_i)
        .order(:form)
        .select
      if forms.size > 0
        summary = "#{Inflection::Type.new(forms.first.type).long_name(:verb)} #{word}"
        old_summary = "#{Inflection::Type.new(forms.first.type).old_class_long_name} #{word}"
        table = Inflection::VERB_FORMS.zip(forms).to_h
      else
        fail = true
      end
    end

    templ "verb"
  end

  get "/pronoun" do |ctx|
    word = ctx.params.query["s"]?.try { |w| HTML.escape w }
    fail = false
    if word
      forms = InflectedEntry
        .where(raw: word, part: Inflection::Part::Pronoun.to_i)
        .order(:form)
        .select
      if forms.size > 0
        summary = "#{Inflection::Type.new(forms.first.type).long_name(:pronoun)} #{word}"
        old_summary = "#{Inflection::Type.new(forms.first.type).old_class_long_name} #{word}"
        table = Inflection::PRONOUN_FORMS.zip(forms).to_h
      else
        fail = true
      end
    end

    templ "pronoun"
  end

  get "/reverse" do |ctx|
    word = ctx.params.query["s"]?.try { |w| HTML.escape w }
    include_old = ctx.params.query["old"]? != nil
    fail = false
    if word
      html = Inflection::Reverse.reverse_html word, include_old
      fail = html.nil?
    end

    templ "reverse"
  end

  get "/docs" do |ctx|
    templ "doc"
  end

  get "/api/jsemb/v2/dict" do |ctx|
    ctx.response.content_type = "application/json"
    ctx.response.status_code = 500
    error = "Unknown error"
    begin
      start = (ctx.params.query["s"]? || 0).to_i
      amount = (ctx.params.query["l"]? || 25).to_i
      raise ArgumentError.new "Parameters can't be negative" if start < 0 || amount < 0
      raise ArgumentError.new "Too many results requested per page" if amount > 100
      d = Dict.get.offset(start)
      d = d.limit(amount) if amount > 0
      dict = d.select
    rescue ex : ArgumentError
      ctx.response.status_code = 400
      error = ex.message
    rescue ex
      error = "Unknown #{ex}"
    else
      ctx.response.status_code = 200
      next {
        "status"   => "ok",
        "response" => {
          "start": start,
          "max":   Dict.get.count.run,
          "limit": amount,
          "dict":  dict,
        },
      }.to_json
    end
    Log.error { error } if ctx.response.status_code == 500
    {
      "status"   => "error",
      "response" => error,
    }.to_json
  end

  get "/api/jsemb/v2/locate/:hash" do |ctx|
    ctx.response.content_type = "application/json"
    ctx.response.status_code = 500
    error = "Unknown error"
    begin
      index = FullEntry.find_by(hash: ctx.params.url["hash"]).try &.num
      raise(ArgumentError.new "Hash not found") unless index
    rescue ex : ArgumentError
      ctx.response.status_code = 400
      error = ex.message
    rescue ex
      error = "Unknown #{ex}"
    else
      ctx.response.status_code = 200
      next {
        "status"   => "ok",
        "response" => index,
      }.to_json
    end
    {
      "status"   => "error",
      "response" => error,
    }.to_json
  end

  get "/api/temporary/v0/soundchange" do |ctx|
    body = ctx.request.body
    next nil if body.nil?
    SoundChange.sound_change body.gets_to_end
  end

  macro entries_common(render)
    entries = Dict.get_raw(lusarian: true)
    templ {{render}}, "entries"
  end

  get "/user/entries" do |ctx|
    next unless Auth.assert_auth ctx

    include_input = true
    edit = nil
    entries_common "make_entry"
  end

  get "/user/entries/edit" do |ctx|
    next unless Auth.assert_auth ctx

    include_input = false
    edit = ctx.params.query["s"]
    entries_common "edit_entry"
  end

  post "/user/entries" do |ctx|
    next unless Auth.assert_auth ctx

    lusarian = ctx.params.body.has_key?("lusarian")
    entry = RawEntry.create! eng: ctx.params.body["en"], sol: ctx.params.body["sol"], extra: ctx.params.body["ex"], l: lusarian
    Dict.expand_entries

    ctx.redirect "/user/entries##{entry.hash}", 303
  end

  post "/user/entries/edit" do |ctx|
    next unless Auth.assert_auth ctx

    lusarian = ctx.params.body.has_key?("lusarian")
    edit = ctx.params.query["s"]
    entry = RawEntry.find! edit
    entry.update! eng: ctx.params.body["en"], sol: ctx.params.body["sol"], extra: ctx.params.body["ex"], l: lusarian
    Dict.expand_entries

    ctx.redirect "/user/entries##{entry.hash}", 303
  end

  get "/user/entries/import" do |ctx|
    next unless Auth.assert_auth ctx

    templ "import"
  end

  post "/user/entries/import" do |ctx|
    next unless Auth.assert_auth ctx

    lines = ctx.params.body["s"]
    lines.split("\n").each do |i|
      next if i.strip.empty?
      fields = i.strip.split("\t")
      RawEntry.create! eng: fields[0], sol: fields[1], extra: fields[2], l: false
    end
    Dict.expand_entries
    ctx.redirect "/user/entries", 303
  end

  get "/user/entries/ex" do |ctx|
    next unless Auth.assert_auth ctx

    en = ctx.params.query["en"]?
    sol = ctx.params.query["sol"]?
    ex = ctx.params.query["ex"]?

    if ex.nil? || !Dict::PARTS_OF_SPEECH.has_key?(ex)
      ctx.flash "Invalid extra", "error"
      ctx.redirect "/user/entries", 303
      next
    end
    part = Inflection::Part.from_extra ex
    if part.nil?
      ctx.flash "This part of speech lacks inflection", "error"
      ctx.redirect "/user/entries", 303
      next
    end

    pos = Dict::PARTS_OF_SPEECH[ex].sub('%', "exception")
    all_forms = Inflection::PART_FORMS[part.to_i]
    real_forms = all_forms.reject(&.in? Inflection::OLD_FORMS_COMBINED)
    optional_forms = all_forms.select(&.in? Inflection::OLD_FORMS_COMBINED)

    templ "exception"
  end

  post "/user/entries/ex" do |ctx|
    en = ctx.params.body["en"]?
    ex = ctx.params.body["ex"]?
    lusarian = ctx.params.body.has_key?("lusarian")

    if ex.nil? || en.nil? || !Dict::PARTS_OF_SPEECH.has_key?(ex)
      ctx.flash "Invalid", "error"
      ctx.redirect "/user/entries/ex", 303
      next
    end
    part = Inflection::Part.from_extra ex
    if part.nil?
      ctx.flash "This part of speech lacks inflection", "error"
      ctx.redirect "/user/entries/ex", 303
      next
    end
    all_forms = Inflection::PART_FORMS[part.to_i]
    real_forms = all_forms.reject(&.in? Inflection::OLD_FORMS_COMBINED)
    optional_forms = all_forms.select(&.in? Inflection::OLD_FORMS_COMBINED)
    real_values = real_forms.to_h { |k| {k, ctx.params.body[k.to_s]?} }
    optional_values = optional_forms.to_h { |k| {k, ctx.params.body[k.to_s]?} }

    p! real_forms
    p! real_values

    if real_values.values.any?(&.nil?)
      ctx.flash "A form wasn't provided", "error"
      ctx.redirect "/user/entries/ex", 303
      next
    end

    values = all_forms.map { |k| real_values[k]? || optional_values[k]? || "-" }
    sol = values[0]

    entry = ExceptionEntry.find_by(sol: sol)
    if entry.nil?
      entry = ExceptionEntry.new
    end
    entry.eng = en
    entry.sol = sol
    entry.lusarian = lusarian
    entry.extra = ex
    entry.forms = values.join(",")
    entry.save!
    p! entry
    Dict.expand_entries

    ctx.redirect "/user/entries", 303
  end
end

Log.setup do |c|
  backend = Log::IOBackend.new

  c.bind "*", :trace, backend
  c.bind "db.*", :info, backend
  c.bind "granite", :info, backend
end
Solerian::Dict.expand_entries

if ENV["CHECK_ONLY"]?.nil?
  SolHTTP.run
end
