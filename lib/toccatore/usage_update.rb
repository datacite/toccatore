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
      
      if total < 1
        text = "No works found for in the Usage Reports Queue."
      end

      error_total = 0
      proccessed_messages = 0
      num_messages = total
      while num_messages != 0 
          processed = process_data(options)
          error_total += processed
          proccessed_messages += 1 if processed == 0
          num_messages -= proccessed_messages
      end
      text = "#{proccessed_messages} works processed with #{error_total} errors for Usage Reports Queue #{queue_url}"

      puts text
      # send slack notification
      options[:level] = total > 0 ? "good" : "warning"
      options[:title] = "Report for #{source_id}"
      send_notification_to_slack(text, options) if options[:slack_webhook_url].present? && error_total != 0

      # return number of works queued
      proccessed_messages
    end

    def process_data(options = {})
      errors = 0 
      message = get_message
      unless message.messages.empty?
        data = get_data(message)
        events = parse_data(data, options)
        errors = push_data(events, options)
        if errors < 1
          delete_message message
        end
      end
      errors
    end

    def get_data reponse 
      body = JSON.parse(reponse.messages[0].body)
      url = body["report_id"]
      host = URI.parse(body["report_id"]).host.downcase
      puts url
      puts host
      puts body
      puts "%%%%%%%%%%"
      Maremma.get(url, timeout: 120, host: host)
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
          puts item
          puts "*************"
          error_total += push_item(item, options) 
        end
        error_total
      end
    end

    def source_id
      "usage_update"
    end

    def format_event type, data, options
      fail "Not type given. Report #{data[:report_id]} not proccessed" if type.blank?
      fail "Access token missing." if options[:source_token].blank?
      fail "Report_id is missing" if data[:report_id].blank?

      { "uuid" => SecureRandom.uuid,
        "message-action" => "add",
        "subj-id" => data[:report_id],
        "subj"=> {
          "pid"=> data[:report_id],
          "issued"=> data[:created]
        },
        "total"=> data[:count],
        "obj-id" => data[:pid],
        "relation-type-id" => type,
        "source-id" => "datacite-usage",
        "source-token" => options[:source_token],
        "occurred-at" => data[:created_at],
        "license" => LICENSE 
      }
    end

    def parse_data(result, options={})
      puts result.status
      puts "*************"
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?
      return [{ "errors" => { "title" => "The report is blank" }}] if result.body.blank?

      items = result.body.dig("data","report","report-datasets")
      header = result.body.dig("data","report","report-header")
      report_id = result.url

      created = header.fetch("created")
      Array.wrap(items).reduce([]) do |x, item|
        data = {}
        data[:doi] = item.dig("dataset-id").first.dig("value")
        data[:pid] = normalize_doi(data[:doi])
        data[:created] = created
        data[:report_id] = report_id
        data[:created_at] = created

        instances = item.dig("performance", 0, "instance")

        return x += [OpenStruct.new(body: { "errors" => "There are too many instances in #{data[:doi]} for report #{report_id}. There can only be 4" })] if instances.size > 8
     
        x += Array.wrap(instances).reduce([]) do |ssum, instance|
          data[:count] = instance.dig("count")
          event_type = "#{instance.dig("metric-type")}-#{instance.dig("access-method")}"
          ssum << format_event(event_type, data, options)
          ssum
        end
      end    
    end

    def push_item(item, options={})
      if item["subj-id"].blank?
        puts OpenStruct.new(body: { "errors" => [{ "title" => "There is no Subject" }] })
        return 1
      elsif options[:access_token].blank?
        puts OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] })
        return 1
      elsif item["errors"].present?
        puts OpenStruct.new(body: { "errors" => [{ "title" => "#{item["errors"]["title"]}" }] })
        return 1
      end

      host = options[:push_url].presence || "https://api.test.datacite.org"
      push_url = host + "/events/" + item["uuid"].to_s
      data = { "data" => {
                  "id" => item["uuid"],
                  "type" => "events",
                  "attributes" => item.except("id") }}
      response = Maremma.put(push_url, data: data.to_json,
                                        bearer: options[:access_token],
                                        content_type: 'application/json',
                                        host: host)
                                  
      if response.status == 201 
        puts "#{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service."
        0
      elsif response.status == 200
        puts "#{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service for update."
        0
      elsif response.body["errors"].present?
        puts "#{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} had an error:"
        puts "#{response.body['errors'].first['title']}"
        1
      end
    end
  end
end
