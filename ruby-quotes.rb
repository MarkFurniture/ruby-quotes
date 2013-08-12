#!/usr/bin/ruby
# encoding: utf-8

# TODO: nickserv auth
# TODO: version
# TODO: ping

require 'socket'
require 'digest'
require 'mongo'

include Mongo

$SAFE = 1

# main irc class
class IRC
	def initialize(server, port=6667, nick="RubyQuotes", channels=[])
		@conf = {
			:server 	=> server,
			:port		=> port,
			:nick		=> nick,
			:channels	=> channels,
			:qFile 		=> "res/quotes.txt",
			:qDelim		=> "|",
			:database	=> "quotes",
			:collection	=> "quotes",
			:admin		=> "mike",
			:n 			=> "\u000F",
			:c			=> "\u0003",
			:b			=> "\u0002"
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
			:privmsg 	=> /^:(.+)!.+@.+\sPRIVMSG\s(#{@conf[:nick]}|#.+?)\s:(.+)$/,
			:nick 		=> /^:mike!.+@.+\sPRIVMSG\s#{@conf[:nick]}\s:nick\s(.+)$/,
			:join 		=> /^:mike!.+@.+\sPRIVMSG\s#{@conf[:nick]}\s:join\s(#.+)$/,
			:part 		=> /^:mike!.+@.+\sPRIVMSG\s#{@conf[:nick]}\s:part\s(#.+)$/
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

		m_out "<#{@conf[:nick]}:#{target}> #{message}"
	end


	def pong(response)
		send "PONG :#{response}"
		m_in "Server ping"
	end


	def nick(nick)
		@conf[:nick] = nick
		send "NICK #{@conf[:nick]}"
		initialise_messages
		m_out "Changing nick to #{nick}"
	end


	def join(channel)
		send "JOIN :#{channel}"
		m_out "Joined #{channel}"
	end


	def part(channel)
		send "PART :#{channel}"
		m_out "Parted #{channel}"
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
		#puts message
		case message.strip
		when @messages[:ping]
			pong $1
		when @messages[:nick]
			nick $1
		when @messages[:join]
			join $1
		when @messages[:part]
			part $1
		when @messages[:privmsg]
			privmsg_in $1, $2, $3
		else
			m_in message
		end
	end


	def get_quote(criteria = nil)
		total = @mongo.count

		case criteria
		when nil
			n = rand(@mongo.count)
			result = @mongo.find_one(:id => total)
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
			matches = @mongo.find(:added_by => /^#{criteria.split('#').last.force_encoding("UTF-8").gsub(/ /, ' ').gsub(/[\*]/, '.*')}$/i).to_a
			result = matches[rand(matches.length)]
		when /^by#/
			matches = @mongo.find(:quote => /<[~&@%+]?#{criteria.split('#').last.force_encoding("UTF-8").gsub(/\s/, "\s").gsub(/[\*]/, '.*')}>/i).to_a
			result = matches[rand(matches.length)]
		else
			matches = @mongo.find(:quote => /#{criteria.gsub(/\:/, '\\:')}/i).to_a
			result = matches[rand(matches.length)]
		end

		#return "#{@conf[:c]}04Quote ##{@conf[:n]}#{result['id']}#{@conf[:c]}04/#{@conf[:n]}#{total}#{@conf[:c]}04:#{@conf[:n]} #{result['quote'].chomp} #{@conf[:c]}04added by#{@conf[:n]} #{result['added_by']} #{@conf[:c]}04at#{@conf[:n]} #{result['added_at']} #{@conf[:c]}04on#{@conf[:n]} #{result['added_on']}" if result
		#return "Quote ##{@conf[:n]}#{result['id']}#{@conf[:c]}04/#{@conf[:n]}#{total}#{@conf[:c]}04:#{@conf[:n]} #{result['quote'].chomp} #{@conf[:c]}04added by#{@conf[:n]} #{result['added_by']} #{@conf[:c]}04at#{@conf[:n]} #{result['added_at']} #{@conf[:c]}04on#{@conf[:n]} #{result['added_on']}" if result
		return "Quote ##{result['id']}/#{total}: #{@conf[:c]}04#{result['quote'].chomp} #{@conf[:n]}added by #{result['added_by']} at #{result['added_at']} on #{result['added_on']}" if result
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
ircbot = IRC.new("irc.calindora.com", 6667, "DudleySpuds", ["#dog"])
ircbot.connect
begin
	ircbot.main
rescue Interrupt
rescue Exception => detail
	puts detail.message
	print detail.backtrace.join("\n")
	retry
end