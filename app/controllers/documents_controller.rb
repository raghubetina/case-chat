# Handing over a file. This is all that remains of the Compiler's generated
# Document CRUD: authoring a document happens in Author::Cases::DocumentsController,
# and reading one happens here.
class DocumentsController < ApplicationController
  before_action :authenticate

  # Downloads go through the app rather than a signed Active Storage URL: a
  # signed URL keeps working after the student loses access, and "you only see
  # what you earned" is the product, not a detail.
  # Only attached files are served here. A file_url is author-supplied, so
  # redirecting to it would make this app an open redirect — the views render
  # it as an ordinary outbound link instead, where a student can see where
  # they are going before they click.
  def download
    document = Document.includes(:case_study).find(params[:id])
    authorize! document, to: :show?

    if document.file.attached?
      redirect_to rails_blob_path(document.file, disposition: "attachment")
    else
      redirect_back_or_to(cases_path, alert: t("documents.missing"))
    end
  end
end
