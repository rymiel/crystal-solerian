require "./db"
require "crypto/bcrypt/password"

module Solerian::Auth
  class User < Granite::Base
    connection solhttp
    table user

    column id : Int64, primary: true
    column name : String
    column pass : String
  end

  alias Passwd = Crypto::Bcrypt::Password

  def self.check_login(ctx)
    ctx.response.status_code = 400

    username = ctx.params.body["username"]?
    secret = ctx.params.body["secret"]?
    return "No" if username.nil? || secret.nil?

    user = User.find_by(name: username)
    return "No" if user.nil?

    pass = Passwd.new user.pass
    if pass.verify secret
      ctx.session.string("user", user.name)
      ctx.flash "Logged in as #{user.name} successfully.", "success"
      ctx.redirect "/", 303
      return
    end

    "No"
  end

  def self.user?(ctx)
    !self.username(ctx).nil?
  end

  def self.assert_auth(ctx)
    if self.username(ctx).nil?
      ctx.response.status_code = 401
      ctx.response.close
      return false
    end
    true
  end

  def self.username(ctx)
    ctx.session.string?("user")
  end
end
