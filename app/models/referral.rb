class Referral < ApplicationRecord
  belongs_to :referring_contact, class_name: "Contact", foreign_key: "referring_contact_id", optional: false
  belongs_to :referred_contact, class_name: "Contact", foreign_key: "referred_contact_id", optional: false
end
