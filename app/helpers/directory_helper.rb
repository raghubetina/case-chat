module DirectoryHelper
  # The design identifies people by monogram avatars throughout.
  def initials_for(name)
    name.to_s.split.filter_map { |part| part[0] }.first(2).join.upcase
  end

  # Attached files stream through the app so the policy decides each time.
  # An external link is exactly that — outbound, visible, and rel-protected.
  def document_link(document, label:, css: "btn btn-outline btn-sm")
    if document.file.attached?
      link_to label, download_document_path(document), class: css
    elsif document.file_url.present?
      link_to label, document.file_url, class: css,
        target: "_blank", rel: "noopener noreferrer"
    else
      tag.span(t("documents.missing"), class: "text-sm text-faint")
    end
  end

  def message_summary(conversation, count)
    return t("threads.summary.not_contacted") if conversation.nil?
    return t("threads.summary.new_contact") if count.zero?

    t("threads.summary.messages", count: count)
  end
end
