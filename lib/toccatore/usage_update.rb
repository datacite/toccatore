require_relative 'base'

require 'aws-sdk-sqs'

module Toccatore
  class UsageUpdate < Base
    LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

    # def get_query_url(options={})
    #   updated = "updated:[#{options[:from_date]}T00:00:00Z TO #{options[:until_date]}T23:59:59Z]"
    #   fq = "#{updated} AND has_metadata:true AND is_active:true"

    #   if options[:doi].present?
    #     q = "doi:#{options[:doi]}"
    #   elsif options[:query].present?
    #     q = options[:query]
    #   else
    #     q = query
    #   end

    #   params = { q: q,
    #              start: options[:offset],
    #              rows: options[:rows],
    #              fl: "doi,resourceTypeGeneral,relatedIdentifier,nameIdentifier,minted,updated",
    #              fq: fq,
    #              wt: "json" }
    #   url +  URI.encode_www_form(params)
    # end

    def get_total(options={})
      # query_url = get_query_url(options.merge(rows: 0))
      # result = Maremma.get(query_url, options)
      # result.body.fetch("data", {}).fetch("response", {}).fetch("numFound", 0)
      sqs = Aws::SQS::Client.new(region: ENV['AWS_REGION'].to_s)
      # resp = sqs.receive_message(queue_url: url, max_number_of_messages: 100, wait_time_seconds: 10)
      # resp.messages.size
      req = sqs.get_queue_attributes(
        {
          queue_url: url, attribute_names: 
            [
              'ApproximateNumberOfMessages', 
              'ApproximateNumberOfMessagesNotVisible'
            ]
        }
      )
    
      msgs_available = req.attributes['ApproximateNumberOfMessages']
      msgs_in_flight = req.attributes['ApproximateNumberOfMessagesNotVisible']
      msgs_available.size
    end

    def queue_jobs(options={})
      # options[:offset] = options[:offset].to_i || 0
      # options[:rows] = options[:rows].presence || job_batch_size
      # options[:from_date] = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
      # options[:until_date] = options[:until_date].presence || Time.now.to_date.iso8601

      total = get_total(options)

      if total > 0
        # walk through paginated results
        total_pages = (total.to_f / job_batch_size).ceil
        error_total = 0

        (0...total_pages).each do |page|
          options[:offset] = page * job_batch_size
          options[:total] = total
          error_total += process_data(options)
        end
        text = "#{total} works processed with #{error_total} errors for date range #{options[:from_date]} - #{options[:until_date]}."
      else
        text = "No works found for in the queue."
      end

      # send slack notification
      options[:level] = total > 0 ? "good" : "warning"
      options[:title] = "Report for #{source_id}"
      send_notification_to_slack(text, options) if options[:slack_webhook_url].present?

      # return number of works queued
      total
    end

    def process_data(options = {})
      data = get_data(options.merge(timeout: timeout))
      data = parse_data(data, options)

      return [OpenStruct.new(body: { "data" => [] })] if data.empty?

      push_data(data, options)
    end

    def get_data(options={})
      # query_url = get_query_url(options)
      # Maremma.get(query_url, options)
      event = sqs.receive_message(queue_url: url, max_number_of_messages: 100, wait_time_seconds: timeout)
      report_id = event.dig(:message_body, :report_id)
      Maremma.get(get_metrics_query_url(report_id))
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

    def url
      # "https://search.datacite.org/api?"
      # "sqs.#{ENV['AWS_REGION'].to_s}.amazonaws.com"
      sqs = Aws::SQS::Client.new
      sqs.get_queue_url(queue_name: "#{Rails.env}_sashimi").queue_url
    end

    def get_metrics_query_url(options={})
      metrics_url + options[:report_id]
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
        "message_action" => "create",
        "subj_id" => data[:report_id],
        "subj"=> {
          "pid"=> data[:report_id],
          "issued"=> data[:created],
          "type"=> type
        },
        "total"=> data[:count],
        "obj_id" => data[:pid],
        "relation_type_id" => "tallies",
        "source_id" => "datacite",
        "source_token" => options[:source_token],
        "occurred_at" => data[:created_at],
        "license" => LICENSE 
      }
    end


    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.body.dig("report","report-datasets")
      header = result.body.dig("report","report-header")
      report_id = metrics_url + result.body.dig("report","id")

      created = header.fetch("created")
      Array.wrap(items).reduce([]) do |x, item|
        data = {}
        data[:doi] = item.dig("dataset-id").first.dig("value")
        data[:pid] = normalize_doi(data[:doi])
        data[:created] = created
        data[:report_id] = report_id
        data[:created_at] = "2015-04-07T12:22:40Z"

        instances = item.dig("performance").first.dig("instance")
     
        x += Array.wrap(instances).reduce([]) do |ssum, instance|
          data[:count] = instance.dig("count")
          evetn_type = "#{instance.dig("metric-type")}-#{instance.dig("access-method")}"
          ssum << format_event(evetn_type, data, options)
        end
      end    
    end

    def push_item(item, options={})
      return OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] }) if options[:access_token].blank?

      host = options[:push_url].presence || "https://api.test.datacite.org"
      push_url = host + "/events"
      puts item.to_json
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
        puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} pushed to Event Data service."
        0
      elsif response.body["errors"].present?
        puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} had an error:"
        puts "#{response.body['errors'].first['title']}"
        1
      end
    end
  end
end
