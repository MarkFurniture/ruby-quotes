# class to grab config from file
class ConfigParser
	def initialize(filename, delim="=")
		@config_file = filename
		@config = {}
		@delim = delim
	end

	def parse
		open(@config_file).each_line do |line|
			splat = line.chomp.split(/\s*#{@delim}\s*/)

			@config["#{splat.delete_at(0)}"] = splat.join(@delim)
		end

		p @config

		return @config
	end
end

ConfigParser.new('ruby-quotes.conf').parse