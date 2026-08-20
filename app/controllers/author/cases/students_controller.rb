module Author
  module Cases
    # One student's transcripts, for an author standing in front of a row of
    # the cohort table wondering what that person actually said.
    class StudentsController < Author::BaseController
      def show
        @case_study = CaseStudy.find(params[:case_id])
        authorize! @case_study, to: :update?

        # Reached through an enrollment in this case rather than by user id.
        # Authoring a case grants a view of the people taking it, not a lookup
        # of arbitrary users, and the difference is one WHERE clause.
        enrolled = Enrollment.where(case_study_id: @case_study.id, user_id: params[:id]).exists?
        raise ActiveRecord::RecordNotFound unless enrolled

        @student = User.find(params[:id])
        @report = StudentReport.new(@case_study, @student)
      end
    end
  end
end
