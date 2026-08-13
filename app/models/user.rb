# == Schema Information
#
# Table name: users
#
#  id         :uuid             not null, primary key
#  email      :string           not null
#  full_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_many :authored_cases, class_name: "Case", foreign_key: :author_id,
    inverse_of: :author, dependent: :restrict_with_exception
  has_many :enrollments, dependent: :restrict_with_exception
  has_many :test_drives, class_name: "TestDrive", foreign_key: :author_id, inverse_of: :author,
    dependent: :restrict_with_exception

  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true

  before_validation :canonicalize_identity

  private

  def canonicalize_identity
    self.full_name = full_name.to_s.strip
    self.email = email.to_s.strip.downcase
  end
end
