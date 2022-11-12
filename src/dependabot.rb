#!/usr/bin/env ruby
# This script is designed to loop through all dependencies Github
# Terraform project and create according pull requests

require "dependabot/file_fetchers"
require "dependabot/file_parsers"
require "dependabot/update_checkers"
require "dependabot/file_updaters"
require "dependabot/pull_request_creator"
require "dependabot/omnibus"
require 'json'
require 'octokit'

# Utilize the github env variable per default
repo_name = ENV["GITHUB_REPOSITORY"]
if repo_name.empty?
  print "GITHUB_REPOSITORY needs to be set"
  exit(1)
end

# Directory where the base dependency files are.
directory = ENV["INPUT_DIRECTORY"] || "/"
directory = directory.gsub(/\\n/, "\n")
if directory.empty?
  print "The directory needs to be set"
  exit(1)
end

# Define the target branch
target_branch = ENV["GITHUB_HEAD_REF"]
if target_branch.empty?
  print "This action is only supported for pull requests!"
  exit(1)
end

# Token to be used for fetching repository files / creating pull requests
repo_token = ENV["INPUT_TOKEN"]
if repo_token.empty?
  print "A github token needs to be provided"
  exit(1)
end

credentials_repository = [
  {
    "type" => "git_source",
    "host" => "github.com",
    "username" => "x-access-token",
    "password" => repo_token
  }
]

credentials_dependencies = []

# Token to be used for fetching dependencies from github
dependency_token = ENV["INPUT_GITHUB_DEPENDENCY_TOKEN"]
unless dependency_token.empty?
  credentials_dependencies.push(
    {
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => dependency_token
    }
  )
end

def update(source, credentials_repository, credentials_dependencies)
  available_updates = []
  # Hardcode the package manager to terraform
  package_manager = "terraform"

  ##############################
  # Fetch the dependency files #
  ##############################
  begin
    puts "Fetching #{package_manager} dependency files for #{source}"
    fetcher = Dependabot::FileFetchers.for_package_manager(package_manager).new(
      source: source,
      credentials: credentials_repository,
    )
    files = fetcher.files
    puts "Parsing dependencies information"
  rescue
    puts "  - Skipping: nothing terraform related found in!"
    exit(0)
  end


  ##############################
  # Parse the dependency files #
  ##############################
  puts "  - Parsing dependencies information"
  parser = Dependabot::FileParsers.for_package_manager(package_manager).new(
    dependency_files: files,
    source: source,
    credentials: credentials_repository,
  )
  dependencies = parser.parse

  dependencies.select(&:top_level?).each do |dep|
    #########################################
    # Get update details for the dependency #
    #########################################
    checker = Dependabot::UpdateCheckers.for_package_manager(package_manager).new(
      dependency: dep,
      dependency_files: files,
      credentials: credentials_dependencies,
    )

    next if checker.up_to_date?

    requirements_to_unlock =
      if !checker.requirements_unlocked_or_can_be?
        if checker.can_update?(requirements_to_unlock: :none) then :none
        else :update_not_possible
        end
      elsif checker.can_update?(requirements_to_unlock: :own) then :own
      elsif checker.can_update?(requirements_to_unlock: :all) then :all
      else :update_not_possible
      end

    next if requirements_to_unlock == :update_not_possible

    updated_deps = checker.updated_dependencies(
      requirements_to_unlock: requirements_to_unlock
    )
    updated_deps.each do |upd_dep|
      if upd_dep.requirements[0][:source][:type] == "registry" then
        print " - Update available for: #{upd_dep.requirements[0][:source][:module_identifier]} #{upd_dep.previous_version} -> #{upd_dep.version}\n"
        upd_str = "Update available for: #{upd_dep.requirements[0][:source][:module_identifier]} #{upd_dep.previous_version} -> #{upd_dep.version}"
      else
        print " - Update available for: #{upd_dep.requirements[0][:source][:url]} #{upd_dep.previous_version} -> #{upd_dep.version}\n"
        upd_str = "Update available for: #{upd_dep.requirements[0][:source][:url]} #{upd_dep.previous_version} -> #{upd_dep.version}"
      end
      available_updates.push(upd_str)
    end
  end
  return available_updates
end

puts "  - Fetching dependency files for #{repo_name}"
available_updates = []
directory.split("\n").each do |dir|
  puts "  - Checking #{dir} ..."

  source = Dependabot::Source.new(
    provider: "github",
    repo: repo_name,
    directory: dir.strip,
    branch: target_branch,
  )
  available_updates.push(update(source, credentials_repository, credentials_dependencies))
end
if available_updates.join("") != "" then
  print "\n\n Updates available for the following:\n"
  first_line = "## Available updates for the following modules used in this repository:\n\n"
  gh_context = JSON.parse(ENV["INPUT_GH_CONTEXT"]);
  comment_body = "#{first_line} #{available_updates.join("\n")}"

  client = Octokit::Client.new(:access_token => ENV["INPUT_TOKEN"])

  pr_comments = client.issue_comments(ENV["GITHUB_REPOSITORY"], gh_context['event']['number'],{
    :sort => 'updated',
    :direction => 'desc'
  })
  comment_id = 0
  if pr_comments.length > 0 then
    pr_comments.each do |comment|
      if comment[":user"][":login"] == "github-actions[bot]" then
        if comment[":body"].start_with?(first_line) then
          comment_id = comment[":id"]
        end
      end
    end
  end
  if comment_id > 0 then
    client.update_comment(ENV["GITHUB_REPOSITORY"], comment_id, comment_body)
  else
    client.add_comment(ENV["GITHUB_REPOSITORY"], gh_context['event']['number'], comment_body)
  end
  print available_updates.join("\n")
end
puts "  - Done"
