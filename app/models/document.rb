# == Schema Information
#
# Table name: documents
#
#  id             :uuid             not null, primary key
#  byte_size      :integer
#  description    :string
#  file_name      :string           not null
#  file_url       :string
#  given_at_start :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  case_study_id  :uuid             not null
#
# Indexes
#
#  index_documents_on_case_study_id  (case_study_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_study_id => case_studies.id) ON DELETE => cascade
#
class Document < ApplicationRecord
  # Case exhibits: the PDFs, spreadsheets and CSVs a contact hands over.
  MAX_BYTES = 25.megabytes
  ALLOWED_TYPES = %w[
    application/pdf
    text/csv
    text/plain
    text/markdown
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/msword
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    image/png
    image/jpeg
  ].freeze

  # has_one_attached brings dependent: :purge_later, which is exactly why
  # case_study.documents declares dependent: :destroy rather than leaning on the
  # database cascade: a cascade deletes the row without running callbacks, and
  # the blob would sit in storage forever with nothing pointing at it.
  has_one_attached :file

  belongs_to :case_study, class_name: "CaseStudy", optional: false

  has_many :share_rules, class_name: "ShareRule", dependent: :destroy
  has_many :document_shares, class_name: "DocumentShare", dependent: :destroy

  validates :file_name, presence: true
  validates :byte_size, comparison: {greater_than: 0}, allow_nil: true
  validates :given_at_start, inclusion: {in: [true, false]}
  # This value becomes an href. Anchored at both ends and whitespace-free on
  # purpose: \A alone would let a newline carry a second, unchecked line along
  # with it.
  validates :file_url, format: {with: %r{\Ahttps?://\S+\z}i}, allow_blank: true

  # Active Storage ships no validation of its own. This is ours.
  validate :attachment_within_limits

  before_validation :sync_metadata_from_attachment

  # A document is either an uploaded file or a link to one held elsewhere.
  def downloadable? = file.attached? || file_url.present?

  def extension_label
    File.extname(file_name.to_s).delete(".").upcase.presence
  end

  private

  def attachment_within_limits
    return unless file.attached?

    if file.byte_size > MAX_BYTES
      errors.add(:file, :too_large, count: MAX_BYTES / 1.megabyte)
    end

    unless ALLOWED_TYPES.include?(file.content_type)
      errors.add(:file, :unsupported_type, type: file.content_type)
    end
  end

  # These columns exist so a document reads sensibly before anything is
  # attached, and in lists that deliberately do not load blobs. Once a file is
  # attached they should agree with it.
  def sync_metadata_from_attachment
    return unless file.attached?

    self.file_name = file.filename.to_s if file_name.blank?
    self.byte_size = file.byte_size
  end
end
