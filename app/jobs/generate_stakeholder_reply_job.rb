class GenerateStakeholderReplyJob < ApplicationJob
  queue_as :ai

  limits_concurrency key: ->(model_run_id) { model_run_id }, duration: 15.minutes

  def perform(model_run_id)
    ConversationRuns::Generate.call(model_run_id:)
  end
end
