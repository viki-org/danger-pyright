# frozen_string_literal: true

require "pathname"
ROOT = Pathname.new(File.expand_path("..", __dir__))
$:.unshift("#{ROOT}lib".to_s)
$:.unshift("#{ROOT}spec".to_s)

require "bundler/setup"
require "pry"

require "rspec"
require "danger"

if `git remote -v` == ""
  puts "You cannot run tests without setting a local git remote on this repo"
  puts "It's a weird side-effect of Danger's internals."
  exit(0)
end

RSpec.configure do |config|
  config.filter_gems_from_backtrace "bundler"
  config.color = true
  config.tty = true
end

require "danger_plugin"

def testing_ui
  @output = StringIO.new
  def @output.winsize
    [20, 9999]
  end

  cork = Cork::Board.new(out: @output)
  def cork.string
    out.string.gsub(/\e\[([;\d]+)?m/, "")
  end
  cork
end

def testing_env
  {
    "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true",
    "TRAVIS_PULL_REQUEST" => "800",
    "TRAVIS_REPO_SLUG" => "artsy/eigen",
    "TRAVIS_COMMIT_RANGE" => "759adcbd0d8f...13c4dc8bb61d",
    "DANGER_GITHUB_API_TOKEN" => "123sbdq54erfsd3422gdfio"
  }
end

def testing_dangerfile
  env = Danger::EnvironmentManager.new(testing_env)
  Danger::Dangerfile.new(env, testing_ui)
end
