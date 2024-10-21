require "kemal"

Kemal.config.env = "production"
Kemal.config.powered_by_header = false
error 500 { }

module Solerian
  Log = ::Log.for self

  def self.redirect(ctx, path)
    ctx.response.content_type = "text/plain; charset=utf-8"
    ctx.redirect "https://solerian.rymiel.space/##{path}", 301, body: "This website has been shut down in favor of the refactored solerian.rymiel.space website."
  end

  get "/" do |ctx|
    redirect ctx, "/"
  end

  get "/noun" do |ctx|
    word = ctx.params.query["s"]?.try { |w| URI.encode_path_segment w }
    if word
      redirect ctx, "/w/#{word}"
    else
      redirect ctx, "/"
    end
  end

  get "/verb" do |ctx|
    word = ctx.params.query["s"]?.try { |w| URI.encode_path_segment w }
    if word
      redirect ctx, "/w/#{word}"
    else
      redirect ctx, "/"
    end
  end

  get "/pronoun" do |ctx|
    word = ctx.params.query["s"]?.try { |w| URI.encode_path_segment w }
    if word
      redirect ctx, "/w/#{word}"
    else
      redirect ctx, "/"
    end
  end

  get "/reverse" do |ctx|
    query = ctx.params.query["s"]?.try { |w| URI.encode_path_segment w }
    if query
      redirect ctx, "/reverse/#{query}"
    else
      redirect ctx, "/reverse"
    end
  end

  get "/docs" do |ctx|
    # not yet functional but maybe one day
      redirect ctx, "/docs"
  end

  get "/api/*" do |ctx|
    ctx.response.content_type = "application/json"
    ctx.response.status_code = 410
    {
      "status"   => "error",
      "response" => "API shut down",
    }.to_json
  end

  error 404 do |ctx|
    redirect ctx, "/"
  end
end

Kemal.run
