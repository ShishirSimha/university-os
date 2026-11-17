# Dump `CREATE SCHEMA IF NOT EXISTS` so test databases (including parallel
# worker databases) can load db/schema.rb when `library` is not there yet.
# Plain `create_schema` fails once the schema already exists.
ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/postgresql/schema_dumper"

  ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.class_eval do
    def schemas(stream)
      schema_names = @dump_schemas - [ "public" ]
      return if schema_names.empty?

      schema_names.sort.each do |name|
        next unless name.match?(/\A[a-z_][a-z0-9_]*\z/)

        stream.puts %(  connection.execute("CREATE SCHEMA IF NOT EXISTS #{name}"))
      end
      stream.puts
    end
  end
end
