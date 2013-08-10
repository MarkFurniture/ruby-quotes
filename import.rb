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

	def import
		mongo_client = MongoClient.new("localhost")
		mongo_db = mongo_client.db(@conf[:database])
		mongo = mongo_db[@conf[:collection]]

		@lines.each_with_index do |line, i|
			splat = line.split(@conf[:delim])

			mongo.insert({
				'id'		=> i,
				'added_by'	=> splat.delete_at(0),
				'added_at'	=> splat.delete_at(0),
				'quote'		=> splat
			})
		end
	end
end

i = Importer.new
i.read_file "res/quotes.txt"
i.import