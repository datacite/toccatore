require_relative 'base'


module Toccatore
  class UsageUpdate < Base
    include Toccatore::Queue
    LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"


    def initialize options={}
      @sqs = queue options
    end

    def queue_jobs(options={})

      total = get_total(options)
      
      while total > 0
        # walk through paginated results
        total_pages = (total.to_f / job_batch_size).ceil
        error_total = 0

        (0...total_pages).each do |page|
          options[:offset] = page * job_batch_size
          options[:total] = total
          error_total += process_data(options)
        end
        text = "#{total} works processed with #{error_total} errors for Usage Reports Queue"
      end

      #   text = "No works found for in the queue."
      # end

      # send slack notification
      options[:level] = total > 0 ? "good" : "warning"
      options[:title] = "Report for #{source_id}"
      send_notification_to_slack(text, options) if options[:slack_webhook_url].present?

      # return number of works queued
      total
    end

    def process_data(options = {})
      message = get_message
      data = get_data(message)
      data = parse_data(data, options)

      return [OpenStruct.new(body: { "data" => [] })] if data.empty?

      push_data(data, options)
      delete_message message
    end

    def get_data reponse 
      return OpenStruct.new(body: { "errors" => "Queue is empty" }) if reponse.messages.empty?

      body = JSON.parse(reponse.messages[0].body)
      Maremma.get(body["report_id"])
    end


    # method returns number of errors
    def push_data(items, options={})
      if items.empty?
        puts "No works found in the Queue."
        0
      elsif options[:access_token].blank?
        puts "An error occured: Access token missing."
        options[:total]
      else
        error_total = 0
        Array(items).each do |item|
          error_total += push_item(item, options)
        end
        error_total
      end
    end

    def metrics_url
      "https://metrics.test.datacite.org/reports/"
    end

    def source_id
      "usage_update"
    end

    def query
      "relatedIdentifier:DOI\\:*"
    end

    def format_event type, data, options
      { "id" => SecureRandom.uuid,
        "message-action" => "add",
        "subj-id" => data[:report_id],
        "subj"=> {
          "pid"=> data[:report_id],
          "issued"=> data[:created]
        },
        "total"=> data[:count],
        "obj-id" => data[:pid],
        "relation-type-id" => type,
        "source-id" => "datacite",
        "source-token" => options[:source_token],
        "occurred-at" => data[:created_at],
        "license" => LICENSE 
      }
    end


    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.body.dig("data","report","report-datasets")
      header = result.body.dig("data","report","report-header")
      report_id = metrics_url + result.body.dig("data","report","id")

      created = header.fetch("created")
      Array.wrap(items).reduce([]) do |x, item|
        data = {}
        data[:doi] = item.dig("dataset-id").first.dig("value")
        data[:pid] = normalize_doi(data[:doi])
        data[:created] = created
        data[:report_id] = report_id
        data[:created_at] = created

        instances = item.dig("performance").first.dig("instance")

        return x += [OpenStruct.new(body: { "errors" => "There are too many instances. There can only be 4" })] if instances.size > 8
     
        x += Array.wrap(instances).reduce([]) do |ssum, instance|
          data[:count] = instance.dig("count")
          event_type = "#{instance.dig("metric-type")}-#{instance.dig("access-method")}"
          ssum << format_event(event_type, data, options)
        end
      end    
    end

    def push_item(item, options={})
      return OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] }) if options[:access_token].blank?

      host = options[:push_url].presence || "https://api.test.datacite.org"
      push_url = host + "/events"

      if options[:jsonapi]
        data = { "data" => {
                   "id" => item["id"],
                   "type" => "events",
                   "attributes" => item.except("id") }}
        response = Maremma.post(push_url, data: data.to_json,
                                          bearer: options[:access_token],
                                          content_type: 'json',
                                          host: host)
      else
        response = Maremma.post(push_url, data: item.to_json,
                                          bearer: options[:access_token],
                                          content_type: 'json',
                                          host: host)
      end

      # return 0 if successful, 1 if error
      if response.status == 201
        puts "#{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service."
        0
      elsif response.body["errors"].present?
        puts "#{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} had an error:"
        puts "#{response.body['errors'].first['title']}"
        1
      end
    end
  end
end
