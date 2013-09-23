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

		mongo_client = MongoClient.new("localhost")
		mongo_db = mongo_client.db(@conf[:database])
		@mongo = mongo_db[@conf[:collection]]
	end

	def read_file(file)
		@lines = File.open(file, "r").readlines
		puts @lines.length
	end

	def date_format(datetime)
		date_array = datetime.split('/')
		return "20#{date_array[2]}-#{date_array[1]}-#{date_array[0]}"
	end

	def fix_id(index, constraint)
		existing = @mongo.find(constraint)

		existing.each do |quote|
			# p quote
			@mongo.update(
				{
					'id' => quote['id'],
					'added_by' => quote['added_by']
				},
				{
					'id' => index,
					'added_by' => quote['added_by'],
					'added_on' => quote['added_on'],
					'added_at' => quote['added_at'],
					'quote' => quote['quote']
				}
			)
			index += 1
		end
	end

	def find_missing_ids
		existing = @mongo.find().count()

		1.upto(existing) do |id|
			# p quote
			quote = @mongo.find_one({ 'id' => id })

			puts id if (quote.nil?)
			#puts quote
		end

		# mongo.insert(quote) if (existing.nil?)
	end
end

i = Importer.new
# i.read_file "res/quotes.txt"
i.read_file "res/sugarlips.txt"

constraint = { 'added_by' => 'Sugarlips`' }

# i.fix_id 836, constraint
i.find_missing_ids