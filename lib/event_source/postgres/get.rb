module EventSource
  module Postgres
    class Get
      include EventSource::Get

      initializer :batch_size

      dependency :session, Session

      def self.build(batch_size: nil, session: nil)
        new(batch_size).tap do |instance|
          instance.configure(session: session)
        end
      end

      def self.configure(receiver, attr_name: nil, position: nil, batch_size: nil, session: nil)
        attr_name ||= :get
        instance = build(batch_size: batch_size, session: session)
        receiver.public_send "#{attr_name}=", instance
      end

      def configure(session: nil)
        Session.configure self, session: session
      end

      def self.call(stream_name, position: nil, batch_size: nil, session: nil)
        instance = build(batch_size: batch_size, session: session)
        instance.(stream_name, position: position)
      end

      def call(stream_name, position: nil)
        logger.trace { "Getting event data (Position: #{position.inspect}, Stream Name: #{stream_name}, Batch Size: #{batch_size.inspect})" }

        records = get_records(stream_name, position)

        events = convert(records)

        logger.info { "Finished getting event data (Count: #{events.length}, Position: #{position.inspect}, Stream Name: #{stream_name}, Batch Size: #{batch_size.inspect})" }
        logger.info(tags: [:data, :event_data]) { events.pretty_inspect }

        events
      end

      def get_records(stream_name, position)
        logger.trace { "Getting records (Stream: #{stream_name}, Position: #{position.inspect}, Batch Size: #{batch_size.inspect})" }

        select_statement = SelectStatement.build(stream_name, position: position, batch_size: batch_size)

        records = session.execute(select_statement.sql)

        logger.debug { "Finished getting records (Count: #{records.ntuples}, Stream: #{stream_name}, Position: #{position.inspect}, Batch Size: #{batch_size.inspect})" }

        records
      end

      def convert(records)
        logger.trace { "Converting records to event data (Records Count: #{records.ntuples})" }

        events = records.map do |record|
          record['data'] = Deserialize.data(record['data'])
          record['metadata'] = Deserialize.metadata(record['metadata'])
          record['time'] = Time.utc_coerced(record['time'])

          EventData::Read.build record
        end

        logger.debug { "Converted records to event data (Event Data Count: #{events.length})" }

        events
      end

      module Deserialize
        def self.data(serialized_data)
          return nil if serialized_data.nil?
          Transform::Read.(serialized_data, EventData::Hash, :json)
        end

        def self.metadata(serialized_metadata)
          return nil if serialized_metadata.nil?
          Transform::Read.(serialized_metadata, EventData::Hash, :json)
        end
      end

      module Time
        def self.utc_coerced(local_time)
          Clock::UTC.coerce(local_time)
        end
      end
    end
  end
end
