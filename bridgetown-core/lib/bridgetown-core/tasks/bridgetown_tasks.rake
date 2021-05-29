# frozen_string_literal: true

desc "Start the Puma server and Bridgetown watcher"
task :start do
  ARGV.reject! { |arg| arg == "start" }
  if ARGV.include?("--help") || ARGV.include?("-h")
    Bridgetown::Commands::Build.start(ARGV)
    puts "  Using watch mode"
    next
  end

  Bridgetown.logger.writer.enable_prefix
  Bridgetown.logger.info "Starting:", "Bridgetown v#{Bridgetown::VERSION.magenta}" \
                         " (codename \"#{Bridgetown::CODE_NAME.yellow}\")"
  sleep 0.5

  pumapid =
    Process.fork do
      if Bundler.definition.specs.find { |s| s.name == "puma" }
        require "puma/cli"

        cli = Puma::CLI.new []
        cli.run
      else
        puts "** No Rack-compatible server found, falling back on Webrick **"
        Bridgetown::Commands::Serve.start(["-P", "4001", "--quiet", "--no-watch", "--skip-initial-build"])
      end
    end

  unless Bridgetown.env.production?
    Bridgetown::Utils::Aux.group do
      run_process "Frontend", :yellow, "bin/bridgetown frontend:dev"
      run_process "Live", nil, "sleep 7 && yarn sync --color"
    end
    sleep 4 # give Webpack time to boot
  end

  begin
    Bridgetown::Commands::Build.start(["-w"] + ARGV)
  rescue StandardError => e
    Process.kill "SIGINT", pumapid
    sleep 0.5
    raise e
  ensure
    Bridgetown::Utils::Aux.kill_processes
  end

  sleep 0.5 # finish cleaning up
end

desc "Alias of start"
task dev: :start

desc "Prerequisite task which loads site and provides automation"
task :environment do
  class HammerActions < Thor
    include Thor::Actions
    include Bridgetown::Commands::Actions

    def self.source_root
      Dir.pwd
    end

    def self.exit_on_failure?
      true
    end

    private

    def site
      @site ||= Bridgetown::Site.new(Bridgetown.configuration)
    end
  end

  define_singleton_method :automation do |*args, &block|
    @hammer ||= HammerActions.new
    @hammer.instance_exec(*args, &block)
  end

  define_singleton_method :site do
    @hammer ||= HammerActions.new
    @hammer.site
  end
end