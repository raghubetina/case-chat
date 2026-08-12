# == Schema Information
#
# Table name: users
#
#  id         :uuid             not null, primary key
#  email      :string           not null
#  full_name  :string           not null
#  program    :string
#  status     :integer          default("unverified"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  include Rodauth::Rails.model

  enum :status, {unverified: 1, verified: 2}, prefix: :account

  has_many :authored_cases, class_name: "CaseStudy", foreign_key: "author_id", dependent: :restrict_with_error
  has_many :enrollments, class_name: "Enrollment", dependent: :destroy

  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, allow_nil: true
  validates :status, inclusion: {in: statuses.keys}

  normalizes :full_name, with: -> { it.strip.presence }
  normalizes :email, with: -> { it.strip.downcase.presence }
end
