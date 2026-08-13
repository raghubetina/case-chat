module Author
  # Everything under /author is authoring: you are here because you own the
  # case, not because you are enrolled in it.
  class BaseController < ApplicationController
    include AuthoringWorkspace

    before_action :authenticate

    private

    def authored_case!
      case_study = CaseStudy.find(params[:case_id] || params[:id])
      authorize! case_study, to: :update?
      case_study
    end
  end
end
