# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerPyright do
    it "should be a plugin" do
      expect(Danger::DangerPyright.new(nil)).to be_a Danger::Plugin
    end

    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @pyright = @dangerfile.pyright
      end

      context "pyright not installed" do
        before do
          allow(@pyright).to receive(:`).with("which pyright").and_return("")
        end
      end

      context "pyright installed" do
        before do
          allow(@pyright).to receive(:`).with("which pyright").and_return("/usr/local/bin/pyright")
        end

        describe "lint" do
          it "runs lint from current directory by default" do
            json_output = '{"generalDiagnostics": []}'
            expect(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)
            @pyright.lint
          end

          it "runs lint from a custom directory" do
            json_output = '{"generalDiagnostics": []}'
            expect(@pyright).to receive(:`).with("pyright my/custom/directory --outputjson").and_return(json_output)

            @pyright.base_dir = "my/custom/directory"
            @pyright.lint
          end

          it "handles a custom config file" do
            json_output = '{"generalDiagnostics": []}'
            expect(@pyright).to receive(:`).with("pyright . --outputjson --project my-pyright-config.json").and_return(json_output)
            @pyright.config_file = "my-pyright-config.json"
            @pyright.lint
          end

          it "handles a lint with no errors" do
            json_output = '{"generalDiagnostics": []}'
            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)
            @pyright.lint
            expect(@pyright.status_report[:markdowns].first).to be_nil
          end

          it "comments inline properly" do
            json_output = '{
              "generalDiagnostics": [
                {
                  "file": "./tests/test_matcher.py",
                  "severity": "error",
                  "message": "Cannot assign member \"value\" for type \"str\"",
                  "range": {
                    "start": {"line": 90, "character": 9}
                  }
                }
              ]
            }'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)

            @pyright.lint(use_inline_comments = true)

            message = @pyright.status_report[:messages].first
            expect(message).to eq("error: Cannot assign member `value` for type `str`")
          end
        end

        context "when running on github" do
          it "handles a lint with errors count greater than threshold" do
            json_output = '{
              "generalDiagnostics": [
                {
                  "file": "./tests/test_matcher.py",
                  "severity": "error",
                  "message": "Cannot assign member \"value\" for type \"str\"",
                  "range": {
                    "start": {"line": 90, "character": 9}
                  }
                }
              ]
            }'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)
            allow(@dangerfile.danger).to receive(:scm_provider).and_return("github")
            allow(@dangerfile.github).to receive(:html_link)
              .with("./tests/test_matcher.py#L90", full_path: false)
              .and_return("fake_link_to:test_matcher.py#90")

            @pyright.lint

            markdown = @pyright.status_report[:markdowns].first
            expect(markdown.message).to include("## DangerPyright found issues")
            expect(markdown.message).to include("| fake_link_to:test_matcher.py#90 | 90 | 9 | error | Cannot assign member `value` for type `str` |")
          end
        end

        context "when running outside github" do
          it "handles a lint with errors" do
            json_output = '{
              "generalDiagnostics": [
                {
                  "file": "./tests/test_matcher.py",
                  "severity": "error",
                  "message": "Cannot assign member \"value\" for type \"str\"",
                  "range": {
                    "start": {"line": 90, "character": 9}
                  }
                }
              ]
            }'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)
            allow(@dangerfile.danger).to receive(:scm_provider).and_return("fake_provider")

            @pyright.lint

            markdown = @pyright.status_report[:markdowns].first
            expect(markdown.message).to include("## DangerPyright found issues")
            expect(markdown.message).to include("| ./tests/test_matcher.py | 90 | 9 | error | Cannot assign member `value` for type `str` |")
          end

          it "handles a lint with errors count lesser than threshold" do
            json_output = '{
              "generalDiagnostics": [
                {
                  "file": "./tests/test_matcher.py",
                  "severity": "error",
                  "message": "Cannot assign member \"value\" for type \"str\"",
                  "range": {
                    "start": {"line": 90, "character": 9}
                  }
                }
              ]
            }'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)

            @pyright.threshold = 5
            @pyright.lint

            expect(@pyright.status_report[:markdowns].first).to be_nil
          end
        end

        describe "count_errors" do
          it "handles errors showing only count" do
            json_output = '{
              "generalDiagnostics": [
                {
                  "file": "./tests/test1.py",
                  "severity": "error",
                  "message": "Error 1",
                  "range": {"start": {"line": 1, "character": 1}}
                },
                {
                  "file": "./tests/test2.py",
                  "severity": "error",
                  "message": "Error 2",
                  "range": {"start": {"line": 2, "character": 2}}
                },
                {
                  "file": "./tests/test3.py",
                  "severity": "warning",
                  "message": "Warning 1",
                  "range": {"start": {"line": 3, "character": 3}}
                }
              ]
            }'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)

            @pyright.count_errors

            warning_message = @pyright.status_report[:warnings].first
            expect(warning_message).to include("3 Pyright type checking issues found")
          end

          it "should not report for count_errors if total errors is below configured threshold" do
            json_output = '{
              "generalDiagnostics": [
                {
                  "file": "./tests/test1.py",
                  "severity": "error",
                  "message": "Error 1",
                  "range": {"start": {"line": 1, "character": 1}}
                }
              ]
            }'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)

            @pyright.threshold = 20
            @pyright.count_errors

            expect(@pyright.status_report[:warnings]).to be_empty
          end

          it "should not report anything if there is no error" do
            json_output = '{"generalDiagnostics": []}'

            allow(@pyright).to receive(:`).with("pyright . --outputjson").and_return(json_output)

            @pyright.count_errors

            expect(@pyright.status_report[:warnings]).to be_empty
          end
        end
      end
    end
  end
end
