#!/usr/bin/ruby

# encoding: utf-8
require 'mongo'

class Importer
	include Mongo

	def initialize
		@conf = {
			:database	=> "quotes",
			:collection	=> "quotes",
			:delim		=> "|"
		}
	end

	def read_file(file)
		@lines = File.open(file, "r").readlines
		puts @lines.length
	end

	def date_format(datetime)
		date_array = datetime.split('/')
		return "20#{date_array[2]}-#{date_array[1]}-#{date_array[0]}"
	end

	def import(start_id = 1)
		mongo_client = MongoClient.new("localhost")
		mongo_db = mongo_client.db(@conf[:database])
		mongo = mongo_db[@conf[:collection]]

		@lines.each_with_index do |line, i|
			splat = line.split(@conf[:delim])

			quote = {
				'id'		=> i + start_id,
				'added_by'	=> splat.delete_at(0).gsub(/160.chr/, ' '),
				'added_on'	=> date_format(splat.first.split(',').last),
				'added_at'	=> splat.delete_at(0).split(',').first,
				'quote'		=> splat.join(@conf[:delim]).chomp
			}

			existing = mongo.find_one({
				'quote'		=> quote['quote']
			})

			# puts "inserting: #{quote['quote']}" if (existing.nil?)
			# puts "not inserting: #{quote['quote']}" if (!existing.nil?)

			mongo.insert(quote) if (existing.nil?)
		end
	end
end

i = Importer.new
i.read_file "res/quotes.txt"
i.import