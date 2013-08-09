#!/usr/bin/ruby

require 'socket'
require 'digest'

$SAFE = 1

# set UTF8 encoding if ruby 1.9
if RUBY_VERSION =~ /1.9/
	Encoding.default_external = Encoding::UTF_8
	Encoding.default_internal = Encoding::UTF_8
end

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
			:qDelim		=> "|"
		}

		initialise_messages

		puts "Using config: #{@conf}"
	end

	def initialise_messages
		@messages = {
			:ping 		=> /^PING :(.+)$/i,
			:privmsg 	=> /^:(.+)!.+@.+\sPRIVMSG\s(#{@conf[:nick]}|#.+)\s:(.+)$/
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