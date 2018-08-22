require "faker"
require 'securerandom'


FactoryBot.define do
  factory :event , class: OpenStruct do
      sequence(:uuid) { |n| "#{SecureRandom.uuid}-#{n}" }
      message_action "create"
      sequence(:obj_id) { |n| "#{Faker::Internet.url}#{n}" }
      sequence(:subj_id) { |n| "#{Faker::Internet.url}#{n}" }
      total Faker::Number.number(3)
      subj {{
        "pid" => "fdfdfd",
        "issued" => Faker::Time.between(DateTime.now - 2, DateTime.now),
      }}
      relation_type_id ["total-dataset-investigations-regular","total-dataset-investigations-machine","unique-dataset-investigations-machine","total-dataset-investigations-machine"].sample
      source_id "datacite-usage"
      sequence(:source_token) { |n| "#{SecureRandom.uuid}-#{n}" }
      occurred_at Faker::Time.between(DateTime.now - 2, DateTime.now)
      license "https://creativecommons.org/publicdomain/zero/1.0/"
  end
end
