# frozen_string_literal: true

require "json"

module Danger
  # Find type checking issues in Python files using Pyright.
  #
  # This is done using the [Pyright](https://github.com/microsoft/pyright) static type checker.
  # Results are passed out as a markdown table or inline comments.
  #
  # @example Lint files inside the current directory
  #
  #          pyright.lint
  #
  # @example Lint files inside a given directory
  #
  #          pyright.base_dir = "src"
  #          pyright.lint
  #
  # @example Warns if number of issues is greater than a given threshold
  #
  #          pyright.threshold = 10
  #          pyright.count_errors
  #
  # @example Fails if number of issues is greater than a given threshold
  #
  #          pyright.threshold = 10
  #          pyright.count_errors(should_fail: true)
  #
  # @see  Thomas Joulin/danger-pyright
  # @tags lint, python, pyright, type-checking, static-analysis
  #
  class DangerPyright < Plugin
    MARKDOWN_TEMPLATE = ""\
      "## DangerPyright found issues\n\n"\
      "| File | Line | Column | Severity | Reason |\n"\
      "|------|------|--------|----------|--------|\n"\

    # A custom configuration file to run with pyright
    # By default, pyright will look for pyrightconfig.json or pyproject.toml
    # @return [String]
    attr_accessor :config_file

    # Root directory from where pyright will run.
    # Defaults to current directory.
    # @return [String]
    attr_writer :base_dir

    # Max number of issues allowed.
    # If number of issues is lesser than the threshold, nothing happens.
    # @return [Int]
    attr_writer :threshold

    # Lint all python files inside a given directory. Defaults to "."
    # @return [void]
    #
    def lint(use_inline_comments = false)
      ensure_pyright_is_installed

      errors = run_pyright
      return if errors.empty? || errors.count <= threshold

      if use_inline_comments
        comment_inline(errors)
      else
        print_markdown_table(errors)
      end
    end

    # Triggers a warning/failure if total lint errors found exceedes @threshold
    # @param [Bool] should_fail
    #        A flag to indicate whether it should warn or fail the build.
    #        It adds an entry on the corresponding warnings/failures table.
    # @return [void]
    #
    def count_errors(should_fail = false)
      ensure_pyright_is_installed

      errors = run_pyright
      total_errors = errors.count
      if total_errors > threshold
        message = "#{total_errors} Pyright type checking issues found"
        should_fail ? fail(message) : warn(message)
      end
    end

    def base_dir
      @base_dir || "."
    end

    def threshold
      @threshold || 0
    end

    private

    def run_pyright
      command = "pyright #{base_dir} --outputjson"
      command << " --project #{config_file}" if config_file

      output = `#{command}`
      return [] if output.strip.empty?

      begin
        json_output = JSON.parse(output)
        diagnostics = json_output["generalDiagnostics"] || []

        diagnostics.map do |diagnostic|
          {
            file: diagnostic["file"],
            line: diagnostic.dig("range", "start", "line"),
            column: diagnostic.dig("range", "start", "character"),
            severity: diagnostic["severity"] || "error",
            message: diagnostic["message"]
          }
        end
      rescue JSON::ParserError
        parse_plain_output(output)
      end
    end

    def parse_plain_output(output)
      errors = []
      output.each_line do |line|
        next unless line =~ /^(.+?):(\d+):(\d+)\s*-\s*(\w+):\s*(.+)$/

        errors << {
          file: ::Regexp.last_match(1).strip,
          line: ::Regexp.last_match(2).to_i,
          column: ::Regexp.last_match(3).to_i,
          severity: ::Regexp.last_match(4).downcase,
          message: ::Regexp.last_match(5).strip
        }
      end
      errors
    end

    def ensure_pyright_is_installed
      system "npm install -g pyright" unless pyright_installed?
    end

    def pyright_installed?
      `which pyright`.strip.empty? == false
    end

    def print_markdown_table(errors = [])
      report = errors.inject(MARKDOWN_TEMPLATE) do |out, error|
        file = error[:file]
        line = error[:line]
        column = error[:column]
        severity = error[:severity]
        message = error[:message].gsub('"', "`").gsub("'", "`")

        out += "| #{short_link(file, line)} | #{line} | #{column} | #{severity} | #{message} |\n"
        out
      end

      markdown(report)
    end

    def comment_inline(errors = [])
      errors.each do |error|
        file = error[:file]
        line = error[:line]
        message_text = "#{error[:severity]}: #{error[:message]}"
        message(message_text.strip.gsub('"', "`").gsub("'", "`"), file: file, line: line)
      end
    end

    def short_link(file, line)
      if danger.scm_provider.to_s == "github"
        return github.html_link("#{file}#L#{line}", full_path: false)
      end

      file
    end
  end
end
