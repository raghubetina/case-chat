module Author
  module Cases
    # What this case has spent, and on which stakeholder.
    class UsagesController < Author::BaseController
      def show
        @case_study = CaseStudy.find(params[:case_id])
        authorize! @case_study, to: :update?
        @report = ModelUsageReport.new(@case_study)
      end
    end
  end
end
