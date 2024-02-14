require "spec"
require "../src/solerian/inflection"

alias Inflection = Solerian::Inflection
alias Word = Solerian::Inflection::Word
alias Prop = Solerian::Inflection::Prop

describe Inflection do
  it "correctly handles `amel`" do
    Word.normalize!("amaln").should eq "àmaln"
    Word.normalize!("ámaln").should eq "àmaln"
  end
end

