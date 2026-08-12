module DirectoryHelper
  # The design identifies people by monogram avatars throughout.
  def initials_for(name)
    name.to_s.split.filter_map { |part| part[0] }.first(2).join.upcase
  end

  def message_summary(conversation)
    return t("threads.summary.not_contacted") if conversation.nil?

    count = conversation.messages.size
    return t("threads.summary.new_contact") if count.zero?

    t("threads.summary.messages", count: count)
  end
end
