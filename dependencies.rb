require "pry"

class Analyzer
  require 'pathname'

  attr_reader :directory

  def initialize(directory)
    @directory = directory
    @deps = Hash.new([])
  end

  def collect_dependencies
    Dir["#{@directory}/**/*.rb"].each do |file|
      analyze_file(file)
    end
    @deps
  end

  private

  def analyze_file(file)
    node_name = extract_node_name(file)
    File.readlines(file).each do |line|
      next if comment? line

      node_name = replace_node_name(line, node_name) if class_or_module?(line)

      @deps[node_name] += [line.split[1]] if line.match(/include\s/)
      @deps[node_name] +=  line.split(" ").map { |d| d.match(/^[A-Z][a-zA-Z0-9:]+/)}.compact.map(&:to_s).uniq
    end
  end

  def replace_node_name(line, node_name)
    new_node_name = line.split[1]
    if new_node_name.split("::").last.eql?(node_name)
      @deps[new_node_name] = @deps[node_name]
      @deps.delete(node_name)
      return new_node_name
    end
    node_name
  end

  def extract_node_name(file)
    p = Pathname.new(file)
    file_name_parts = p.basename.sub(p.extname, "").to_s.split("_")
    file_name_parts.map { |s| s.capitalize }.join
  end

  def comment?(line)
    (line =~ /^\s*#/) == 0
  end

  def class_or_module?(line)
    line.match(/^(class|module)/)
  end

  def sql?(line)
    line.match(/(\"|\')/)
  end

end

class DependecyRepresentation
  require 'graphviz'

  def initialize(dependencies)
    @dependencies = dependencies
  end

  def draw_graph
    g = GraphViz::new( "G", :use => 'dot', :mode => 'major', :rankdir => 'LR', :normalize => 'true', :concentrate => 'true', :fontname => 'Arial')
    remove_self_reference!
    @dependencies.each do |key, values|
      root_node = g.add_node(key.to_s, shape: "box")
      values.map do |v|
        child_node = g.add_node(v.to_s, shape: "box")
        g.add_edges(root_node, child_node)
      end
    end
    g.output( :png => "deps.png" )
  end

  private 

  def remove_self_reference!
    @dependencies.each do |k,v|
      v.uniq!
      v.delete(k)
    end
  end
end

analyzer = Analyzer.new("/Users/schlubbi/play/dependencies/")
result = analyzer.collect_dependencies
rep = DependecyRepresentation.new(result)
rep.draw_graph
