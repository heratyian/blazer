module Blazer
  module Adapters
    class SodaAdapter < BaseAdapter
      def run_statement(statement, comment)
        columns = []
        rows = []
        error = nil

        # remove comments manually
        statement = statement.gsub(/--.+/, "")
        # only supports single line /* */ comments
        # regex not perfect, but should be good enough
        statement = statement.gsub(/\/\*.+\*\//, "")

        # remove trailing semicolon
        statement = statement.sub(/;\s*\z/, "")

        # remove whitespace
        statement = statement.squish

        uri = URI(settings["url"])
        uri.query = URI.encode_www_form("$query" => statement)

        req = Net::HTTP::Get.new(uri)
        req["X-App-Token"] = settings["app_token"] if settings["app_token"]

        options = {
          use_ssl: uri.scheme == "https",
          open_timeout: 3,
          read_timeout: 30
        }

        begin
          # use Net::HTTP instead of soda-ruby for types and better error messages
          res = Net::HTTP.start(uri.hostname, uri.port, options) do |http|
            http.request(req)
          end

          if res.is_a?(Net::HTTPSuccess)
            body = JSON.parse(res.body)

            columns = JSON.parse(res["x-soda2-fields"])
            column_types = columns.zip(JSON.parse(res["x-soda2-types"])).to_h

            columns.reject! { |f| f.start_with?(":@") }
            # rows can be missing some keys in JSON, so need to map by column
            rows = body.map { |r| columns.map { |c| r[c] } }

            columns.each_with_index do |column, i|
              if column_types[column] == "number"
                rows.each do |row|
                  v = row[i].to_f
                  row[i] = v == v.to_i ? v.to_i : v
                end
              end
            end
          else
            error = JSON.parse(res.body)["message"] rescue "Bad response: #{res.code}"
          end
        rescue => e
          error = e.message
        end

        [columns, rows, error]
      end

      def preview_statement
        "SELECT * LIMIT 10"
      end

      def tables
        ["all"]
      end
    end
  end
end