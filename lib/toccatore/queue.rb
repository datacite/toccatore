require 'aws-sdk-sqs'

module Toccatore
  module Queue

    def sqs 
      Aws::SQS::Client.new(region: ENV['AWS_REGION'].to_s)
    end

    def get_total options={}
      req = sqs.get_queue_attributes(
        {
          queue_url: queue_url, attribute_names: 
            [
              'ApproximateNumberOfMessages', 
              'ApproximateNumberOfMessagesNotVisible'
            ]
        }
      )

      msgs_available = req.attributes['ApproximateNumberOfMessages']
      msgs_in_flight = req.attributes['ApproximateNumberOfMessagesNotVisible']
      msgs_available.to_i
    end

    def get_message options={}
      sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1, wait_time_seconds: 1)
    end

    def delete_message options={}
      sqs.delete_message({
        queue_url: queue_url,
        receipt_handle: options.messages[0][:receipt_handle]    
      })
    end

    def queue_url
      sqs.get_queue_url(queue_name: "stage_usage").queue_url
    end
  end
end