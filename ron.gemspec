# -*- encoding: utf-8 -*-

require "#{File.dirname(__FILE__)}/lib/ron/version"
Ron::Description=open("README.txt"){|f| f.read[/^==+ ?description[^\n]*?\n *\n?(.*?\n *\n.*?)\n *\n/im,1] }
Ron::Latest_changes="###"+open("History.txt"){|f| f.read[/\A===(.*?)(?====)/m,1] }

Gem::Specification.new do |s|
  s.name = "Ron"
  s.version = Ron::VERSION
  s.date = Time.now.strftime("%Y-%m-%d")
  s.authors = ["Caleb Clausen"]
  s.email = %q{caleb (at) inforadical (dot) net}
  s.summary = "Ruby Object Notation (Ron) is a ruby-based textual format for representing Ruby data."
  s.description = Ron::Description
  s.homepage = %{http://github.com/coatl/ron}
  s.rubyforge_project = %q{ron}

  s.files = `git ls-files`.split
  s.test_files = %w[test/test_all.rb]
  s.require_paths = ["lib"]
  s.extra_rdoc_files = ["README.txt", "COPYING", "GPL"]
  s.has_rdoc = true
  s.rdoc_options = %w[--main README.txt]

  s.rubygems_version = %q{1.3.0}
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

=begin
  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mime-types>, [">= 1.15"])
      s.add_runtime_dependency(%q<diff-lcs>, [">= 1.1.2"])
    else
      s.add_dependency(%q<mime-types>, [">= 1.15"])
      s.add_dependency(%q<diff-lcs>, [">= 1.1.2"])
    end
  else
    s.add_dependency(%q<mime-types>, [">= 1.15"])
    s.add_dependency(%q<diff-lcs>, [">= 1.1.2"])
  end
=end
end
