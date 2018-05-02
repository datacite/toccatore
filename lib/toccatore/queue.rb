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
      msgs_available.size
    end

    def delete_messages options={}
      sqs.delete_message({
        queue_url: queue_url,
        receipt_handle: message.receipt_handle    
      })
    end

    def queue_url
      sqs.get_queue_url(queue_name: "#{Rails.env}_usage").queue_url
    end
  end
end