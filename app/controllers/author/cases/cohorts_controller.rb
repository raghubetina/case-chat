module Author
  module Cases
    # What the whole class did with this case.
    class CohortsController < Author::BaseController
      def show
        @case_study = CaseStudy.find(params[:case_id])
        authorize! @case_study, to: :update?
        @report = CohortReport.new(@case_study)
      end
    end
  end
end
