require "test_helper"
require_relative "domain_test_helper"

class DocumentAttachmentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include DomainTestHelper

  setup do
    @case_study = build_case_study
  end

  def upload(name: "exhibit.pdf", type: "application/pdf", bytes: "%PDF-1.4 fake")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)
  end

  test "attaching a file records its name and size" do
    document = Document.new(case_study: @case_study, file: upload)

    assert document.save
    assert document.file.attached?
    assert_equal "exhibit.pdf", document.file_name
    assert_equal document.file.byte_size, document.byte_size
  end

  test "an explicit name wins over the uploaded filename" do
    document = Document.create!(case_study: @case_study, file_name: "Segment P&L.pdf", file: upload)

    assert_equal "Segment P&L.pdf", document.file_name
  end

  test "refuses a file type that is not a case exhibit" do
    document = Document.new(
      case_study: @case_study, file_name: "malware.exe",
      file: upload(name: "malware.exe", type: "application/x-msdownload", bytes: "MZ")
    )

    assert_not document.valid?
    assert document.errors.of_kind?(:file, :unsupported_type)
  end

  test "refuses a file over the size limit" do
    document = Document.new(
      case_study: @case_study, file_name: "huge.pdf",
      file: upload(bytes: "x" * (Document::MAX_BYTES + 1))
    )

    assert_not document.valid?
    assert document.errors.of_kind?(:file, :too_large)
  end

  test "a document can be a link instead of an upload" do
    document = Document.new(
      case_study: @case_study, file_name: "Exhibit 5.xlsx",
      file_url: "https://lms.example.test/exhibit-5.xlsx"
    )

    assert document.save
    assert document.downloadable?
    assert_not document.file.attached?
  end

  test "a document with neither a file nor a link is not downloadable" do
    document = Document.create!(case_study: @case_study, file_name: "Placeholder.pdf")

    assert_not document.downloadable?
  end

  # The reason case_study.documents declares dependent: :destroy rather than
  # leaning on the database cascade. A cascade deletes the row without running
  # callbacks, and the blob would sit in storage with nothing pointing at it.
  test "destroying a case purges its documents' blobs" do
    Document.create!(case_study: @case_study, file: upload)

    assert_difference "ActiveStorage::Attachment.count", -1 do
      perform_enqueued_jobs { @case_study.destroy! }
    end
  end

  test "destroying a document alone purges its blob" do
    document = Document.create!(case_study: @case_study, file: upload)

    assert_difference "ActiveStorage::Attachment.count", -1 do
      perform_enqueued_jobs { document.destroy! }
    end
  end
end
