class Referral < ApplicationRecord
  belongs_to :referring_contact, class_name: "Contact", optional: false
  belongs_to :referred_contact, class_name: "Contact", optional: false
end
