#!/usr/bin/ruby

# TODO: !addquote
# TODO: nickserv auth
# TODO: join
# TODO: quit
# TODO: nick
# TODO: version
# TODO: ping

require 'socket'
require 'digest'
require 'mongo'

include Mongo

$SAFE = 1

# set UTF8 encoding if ruby 1.9
if RUBY_VERSION =~ /1.9/
	Encoding.default_external = Encoding::UTF_8
	Encoding.default_internal = Encoding::UTF_8
end

### extend existing classes ###
# string to_b dynamic method
class String
	def to_b
		return true if (self == true || self =~ (/(true|t|yes|y|1)$/i))
		return false
		raise ArgumentError.new("Could not parse boolean: \"#{self}\"")
	end
end

# main irc class
class IRC
	def initialize(server, port=6667, nick="Pete_Cabbage", channels=[])
		@conf = {
			:server 	=> server,
			:port		=> port,
			:nick		=> nick,
			:channels	=> channels,
			:qFile 		=> "res/quotes.txt",
			:qDelim		=> "|",
			:database	=> "quotes",
			:collection	=> "quotes"
		}

		mongo_client = MongoClient.new("localhost", 27017)
		mongo_db = mongo_client.db(@conf[:database])
		@mongo = mongo_db[@conf[:collection]]

		initialise_messages

		puts "Using config: #{@conf}"
	end

	def initialise_messages
		@messages = {
			:ping 		=> /^PING :(.+)$/i,
			:privmsg 	=> /^:(.+)!.+@.+\sPRIVMSG\s(#{@conf[:nick]}|#.+)\s:(.+)$/,
			:nick 		=> /todo/,
			:join 		=> /todo/
		}
	end

	### server interaction ###
	### outgoing ###
	def connect
		@con = TCPSocket.open(@conf[:server], @conf[:port])
		send("USER rubybot rubybot rubybot :rubybot")
		nick @conf[:nick]
		sleep 2
		@conf[:channels].each do |channel|
			join channel
		end
	end


	def send(message)
		@con.send("#{message}\n", 0)
		#m_out message
	end


	def privmsg(target, message)
		while (message.length > 0)
			send "PRIVMSG #{target} :#{message.slice!(0..[message.length-1, 440].min)}"
		end
	end


	def pong(response)
		send "PONG :#{response}"
		m_in "Server ping"
	end


	def nick(nick)
		m_out "Changing nick to #{nick}"
		initialise_messages
		send "NICK #{@conf[:nick]}"
	end


	def join(channel)
		send "JOIN :#{channel}"
		m_out "Joined #{channel}"
	end


	### incoming ###
	def privmsg_in(from, target, message)
		case message
		when /^!quote(?:\s?(.+))?/
			quote = get_quote $1
			privmsg target, quote if quote
		when /^!addquote\s(.+)/
			result = addquote from, target, $1
			privmsg target, result
		end

		m_in "<#{from}:#{target}> #{message}"
	end

	def ping_in(target)
	end

	def join_in(nick, channel)
	end

	### processing ###
	def handle(message)
		case message.strip
		when @messages[:ping]
			pong $1
		when @messages[:privmsg]
			privmsg_in $1, $2, $3
		else
			m_in message
		end
	end

	def get_quote(criteria = nil)
		case criteria
		when nil
			n = rand(@mongo.count)
			result = @mongo.find_one(:id => n)
		when /^[\d]+$/
			result = @mongo.find_one(:id => criteria.to_i)
		when /^(on|at)#/
			date = criteria.split('#').last.split(/[-.\/]/)
			date_f = [date[0].rjust(4, '20'), date[1].rjust(2, '0'), date[2].rjust(2, '0')]
			date_r = []
			date_f.each { |d| date_r << ((d =~ /[\*]/) ? '[\d]{2,4}' : d) }

			matches = @mongo.find(:added_on => /#{date_r.join('-')}/).to_a
			result = matches[rand(matches.length)]
		when /^addedby#/
			matches = @mongo.find(:added_by => /#{criteria.split('#').last}/).to_a
			result = matches[rand(matches.length)]
		when /^by#/
			matches = @mongo.find(:quote => /<[~&@%+]?#{criteria.split('#').last}>/).to_a
			result = matches[rand(matches.length)]
		else
			matches = @mongo.find(:quote => /#{criteria}/).to_a
			result = matches[rand(matches.length)]
		end

		return "Quote ##{result['id']}: #{result['quote'].chomp} added by #{result['added_by']} at #{result['added_at']} on #{result['added_on']}" if result
		return nil
	end

	def addquote(from, target, quote)
		date = Time.now.strftime "%F"
		time = Time.now.strftime "%H:%M:%S"
		parsed = {
			'id'		=> @mongo.count,
			'added_by'	=> from,
			'added_on'	=> date,
			'added_at'	=> time,
			'quote'		=> quote
		}

		return "\"#{quote}\" was added to the database at line #{@mongo.count - 1}" if (@mongo.insert(parsed))
		return "Sorry, there was an error adding the quote to database."
	end


	# print info to console
	def m_in(message)
		puts "> #{Time.now} #{message}"
	end


	def m_out(message)
		puts "< #{Time.now} #{message}"
	end



	# main loop
	def main
		while true
			ready = select([@con, $stdin], nil, nil, nil)
			next if (!ready)
			for s in ready[0]
				if (s == $stdin)
					return if $stdin.eof
					s = $stdin.gets
					send s
				elsif (s == @con)
					return if (@con.eof)
					s = @con.gets
					handle(s)
				end
			end
		end
	end
end

# start it up
ircbot = IRC.new("irc.calindora.com", 6667, "Pete_Cabbage", ["#dog"])
ircbot.connect
begin
	ircbot.main
rescue Interrupt
rescue Exception => detail
	puts detail.message
	print detail.backtrace.join("\n")
	retry
end