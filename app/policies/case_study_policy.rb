class CaseStudyPolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = author_of?(record) || student_reading?(record)

  def new? = signed_in?

  # You may only create a case you author.
  def create? = signed_in? && record.author_id == user.id

  def update? = author_of?(record)

  def destroy? = author_of?(record)

  relation_scope do |relation|
    next relation.none unless signed_in?

    # Cases you author, plus published cases you are enrolled in.
    relation.where(author_id: user.id).or(
      relation.where(published: true, id: Enrollment.where(user_id: user.id).select(:case_study_id))
    )
  end

  # Parents you may attach new authoring records to.
  relation_scope(:authored) do |relation|
    next relation.none unless signed_in?

    relation.where(author_id: user.id)
  end
end
