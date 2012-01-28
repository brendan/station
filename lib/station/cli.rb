require "station"
require "optparse"

module Station

  class CLI

    attr_accessor :argv

    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def exit_with(message)
      puts message
      exit(1)
    end

    def exit_with_help
      exit_with "Usage: station <generator> [target] [options]"
      exit(1)
    end

    def run
      exit_with_help unless argv.first.to_s =~ /\A[a-z]/i
      generator_name = argv.shift

      target = argv.shift if argv.first.to_s =~ /\A[a-z]/i

      @station_file = StationFile.load(StationFile.find_station_file)

      generator = @station_file.generators[generator_name]

      exit_with "Unknown generator #{generator_name.inspect}" unless generator

      force  = false
      params = {}

      used_shortcuts = ["-h","-v"]

      parser = OptionParser.new do |parser|
        parser.banner = "Usage: station #{generator_name} [<target>] [options]"
        parser.separator ""
        parser.separator "global options:"
        parser.on "-h", "--help", "Show general and generator-specific help" do
          puts parser
          exit
        end
        parser.on "-v", "--version", "Display 'station' version information" do
          puts Station::VERSION
          exit
        end
        parser.on "-f", "--force", "Overwrite any pre-existing files or paths" do
          session_options
        end
        parser.separator ""

        description = generator.options[:description]
        if description
          parser.separator [generator_name, generator.options[:description]].compact.join(" - ")
          parser.separator ""
        end

        parser.separator "options for #{generator_name}:"
        generator.params.each do |param|
          puts param.inspect
          shortcut = "-#{param.name.chars.first}"
          shortcut = shortcut.upcase if reserved_shortcuts.include?(shortcut)
          shortcut = nil if reserved_shortcuts
          parser_args = shortcut, "--#{param.name} VALUE", param.options[:description]

            parser.on "--#{param.name.chars[0]}", "--#{param.name} VALUE", param.options[:description] do |value|
            params[param.name] = value
          end
        end
      end

      parser.parse!(argv)

      required_and_missing = generator.params.select do |param|
        param.options[:required] and params[param.name].nil?
      end

      unless required_and_missing.empty?
        required_and_missing.each do |param|
          puts "Missing required option --#{param.name}"
        end
        exit 1
      end

      session = generator.new_session(target, params)

      plan = session.plan
      unless plan.valid? or force
        puts plan.describe_conflicts
        exit
      end

      plan.execute!
    end

  end

end
