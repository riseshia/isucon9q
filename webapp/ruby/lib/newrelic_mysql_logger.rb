require 'new_relic/agent/instrumentation/active_record_helper'
require 'new_relic/agent/instrumentation/notifications_subscriber'
require 'securerandom'

module NewrelicMysqlLogger
  def self.enable(file: STDOUT, root_dir: nil, threshold_time: 0)
    Mysql2::Client.prepend(NewrelicMysqlLogger::ClientMethods)
    Mysql2::Statement.prepend(NewrelicMysqlLogger::StatementMethods)
    @root_dir = root_dir
  end

  def self.format_caller
    loc = caller_locations.find {|c| c.path.match?('/gems/') == false && c.absolute_path != __FILE__ }
    return "unknown" unless loc

    path = @root_dir ? loc.absolute_path.sub("#{@root_dir}/", "") : loc.path
    "#{path}:#{loc.lineno}"
  end

  def self.execute(sql, query_options)
    result = nil
    uuid = SecureRandom.uuid

    start_sg(sql, format_caller, query_options, uuid)
    result = yield
    finish_sg(uuid)

    result
  end

  def self.start_segment(sql, name, query_options)
    sql = NewRelic::Helper.correctly_encoded sql
    product, operation, collection = NewRelic::Agent::Instrumentation::ActiveRecordHelper.product_operation_collection_for(name, sql, :mysql2)

    host = query_options[:host]
    port_path_or_id = query_options[:port]
    database = :mysql2

    segment = NewRelic::Agent::Tracer.start_datastore_segment(product: product,
                                             operation: operation,
                                             collection: collection,
                                             host: host,
                                             port_path_or_id: port_path_or_id,
                                             database_name: database)

    segment._notice_sql sql, nil, nil, nil, name
    segment
  end

  def self.start_sg(sql, name, query_options, id)
    return unless NewRelic::Agent.tl_is_execution_traced?

    segment = start_segment(sql, name, query_options)
    push_segment(id, segment)
  end

  def self.finish_sg(id)
    return unless NewRelic::Agent::Tracer.state.is_execution_traced?

    if segment = pop_segment(id)
      segment.finish
    end
  end

  def self.push_segment(id, segment)
    segment_stack[id].push segment
  end

  def self.pop_segment(id)
    segment = segment_stack[id].pop
    segment
  end

  def self.segment_stack
    @queue_key = ['NewRelic', self.class.name, object_id].join('-')
    Thread.current[@queue_key] ||= Hash.new {|h,id| h[id] = [] }
  end

  module ClientMethods
    def prepare(sql)
      super.tap { |stmt| stmt.instance_variable_set(:@_sql, sql) }
    end

    def query(sql, options = {})
      NewrelicMysqlLogger.execute(sql, @query_options) { super }
    end
  end

  module StatementMethods
    def execute(*args)
      NewrelicMysqlLogger.execute(@_sql, @query_options) { super }
    end
  end
end
