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

        # What each thread cost, which used to be a row on the usage page. It
        # belongs next to the conversation it describes rather than in a list
        # that grows with the class. ModelUsageReport already computes this for
        # the whole case in one grouped query; taking the slice is cheaper than
        # a second way of doing the same arithmetic.
        @spend = ModelUsageReport.new(@case_study).thread_rows
          .index_by(&:conversation_id)
      end
    end
  end
end
