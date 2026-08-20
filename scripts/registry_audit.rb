#!/usr/bin/env ruby
# Registry integrity audit for the SIGNATIF requirements/conformance data.
# Exits non-zero on any failure. Run from the repository root.
require 'yaml'
require 'set'

ROOT = File.expand_path('..', __dir__)
DATA = File.join(ROOT, 'sources/data')
SECTIONS = File.join(ROOT, 'sources/sections')
failures = []
fail = ->(msg) { failures << msg }

rc_files = Dir.glob("#{DATA}/*-rc.yaml").sort
cc_files = Dir.glob("#{DATA}/*-cc.yaml").sort

# 1. parse + collect
req_ids = {}
req_names = {}
tests = 0
test_targets = []
rc_files.each do |f|
  d = YAML.safe_load(File.read(f), permitted_classes: [], aliases: false)
  (d['groups'] || []).each do |g|
    (g['scopes'] || []).each do |sc|
      (sc['requirements'] || []).each do |r|
        id = "#{sc['identifier']}/#{r['identifier_fragment']}"
        req_ids[id] = f
        (req_names[r['name']] ||= []) << sc['identifier']
        stmt = r['statement'].to_s
        fail "NO-SHALL #{id}" unless stmt =~ /\bshall\b/
        fail "THIN #{id}" if stmt.split(/\s+/).length < 6
        fail "NON-KEBAB #{id}" unless r['identifier_fragment'] =~ /\A[a-z0-9]+(-[a-z0-9]+)*\z/
      end
    end
  end
end
cc_files.each do |f|
  d = YAML.safe_load(File.read(f), permitted_classes: [], aliases: false)
  (d['groups'] || []).each do |g|
    (g['scopes'] || []).each do |sc|
      (sc['tests'] || []).each do |t|
        tests += 1
        (t['targets'] || []).each { |tg| test_targets << tg }
        fail "TEST-NO-METHOD #{sc['identifier']}/#{t['identifier_fragment']}" if t['method'].to_s.strip.empty?
      end
    end
  end
end
req_count = req_ids.size

# 2. conformance classes match requirements classes per file pair
rc_classes = Set.new
rc_files.each do |f|
  YAML.safe_load(File.read(f))['groups'].each { |g| g['scopes'].each { |sc| rc_classes << sc['identifier'].sub('/req/', '') } }
end
cc_classes = Set.new
cc_files.each do |f|
  YAML.safe_load(File.read(f))['groups'].each { |g| g['scopes'].each { |sc| cc_classes << sc['identifier'].sub('/conf/', '') } }
end
fail "class set mismatch: req-only #{(rc_classes - cc_classes).to_a} conf-only #{(cc_classes - rc_classes).to_a}" unless rc_classes == cc_classes

# 3. dependency closure
defined = Set.new(rc_classes.map { |c| "/req/#{c}" })
rc_files.each do |f|
  YAML.safe_load(File.read(f))['groups'].each do |g|
    g['scopes'].each do |sc|
      (sc['dependencies'] || []).each do |dep|
        fail "dep target missing #{dep} (from #{sc['identifier']})" unless defined.include?(dep)
      end
    end
  end
end

# 4. test targets resolve
test_targets.each { |t| fail "test target missing #{t}" unless req_ids.key?(t) }

# 5. unique requirement names
req_names.each { |n, cs| fail "duplicate requirement name '#{n}' in #{cs.uniq.join(', ')}" if cs.size > 1 }

# 6. requirements == tests
fail "count mismatch: #{req_count} requirements vs #{tests} tests" unless req_count == tests

# 7. bibliography: entries all cited (adoc + yaml)
bib = File.read("#{SECTIONS}/99-bibliography.adoc")
ids = bib.scan(/^\* \[\[\[([a-zA-Z0-9_-]+),/).flatten
corpus = Dir.glob("#{SECTIONS}/*.adoc").reject { |f| File.basename(f) == '99-bibliography.adoc' }.map { |f| File.read(f) }.join("\n")
corpus += Dir.glob("#{DATA}/*.yaml").map { |f| File.read(f) }.join("\n")
ids.each { |i| fail "bib entry uncited: #{i}" unless corpus =~ /<<#{i}(?:,|>>)/ }

# 8. anchors unique outside code fences (fence-aware)
anchors = Hash.new(0)
Dir.glob("#{SECTIONS}/*.adoc").each do |f|
  fence = false
  File.foreach(f) do |line|
    fence = !fence if line.start_with?('----')
    next if fence
    line.scan(/^\[\[([a-zA-Z0-9_-]+)\]\]/).flatten.each { |a| anchors[a] += 1 }
  end
end
anchors.each { |a, n| fail "duplicate anchor #{a} (#{n}x)" if n > 1 }

if failures.any?
  warn "REGISTRY AUDIT FAILED (#{failures.size}):"
  failures.each { |m| warn " - #{m}" }
  exit 1
end
puts "registry audit passed: #{rc_classes.size} classes, #{req_count} requirements, #{tests} tests, #{ids.size} cited bibliography entries"
