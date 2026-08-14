module CaseSeeder
  # What every teaching case needs in order to be loadable: demo accounts that
  # can actually sign in, documents with real bytes behind them, and a report
  # saying what was made.
  #
  # Subclasses supply the case itself — the cast, the referral graph, and the
  # share rules — because that part is the case, not the plumbing.
  class Base
    # The development and test passphrase. It is committed to this repository,
    # so seeding refuses to use it in production — a deployed box that will hand
    # anyone the author account is worse than a box with no cases on it.
    PASSWORD = "case chat demo passphrase".freeze

    def self.password
      ENV.fetch("SEED_PASSWORD") do
        next PASSWORD unless Rails.env.production?

        raise "Set SEED_PASSWORD before seeding demo accounts in production; " \
              "#{name}::PASSWORD is public."
      end
    end

    # Files that ship with the app rather than sitting beside it. A seeder that
    # reaches outside the repo works on a laptop and silently produces
    # documents with no bytes on a deployed box, which is worse than failing.
    SEED_FILES = Rails.root.join("db/seed_files")

    def call
      raise NotImplementedError
    end

    private

    def upsert_user(full_name, email, program: nil)
      user = User.find_or_initialize_by(email: email)
      user.assign_attributes(full_name: full_name, program: program, status: 2)
      user.save!
      ensure_password(user)
      user
    end

    # Rodauth owns password hashes; seeding one directly keeps the demo
    # accounts usable without walking the email verification flow.
    def ensure_password(user)
      exists = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(["SELECT 1 FROM account_password_hashes WHERE id = ?", user.id])
      )
      return if exists

      hash = BCrypt::Password.create(self.class.password)
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql(
          ["INSERT INTO account_password_hashes (id, password_hash) VALUES (?, ?)", user.id, hash]
        )
      )
    end

    def attach_source(document, path)
      return if path.blank?
      return unless File.exist?(path)

      document.file.attach(
        io: File.open(path),
        filename: document.file_name,
        content_type: content_type_for(path)
      )
    end

    def content_type_for(path)
      case File.extname(path).downcase
      when ".pdf" then "application/pdf"
      when ".csv" then "text/csv"
      when ".md" then "text/markdown"
      when ".xlsx" then "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      when ".docx" then "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      else "text/plain"
      end
    end

    def wire_referrals(pairs)
      pairs.each do |from, to, condition|
        referral = Referral.find_or_initialize_by(referring_contact: from, referred_contact: to)
        referral.assign_attributes(condition: condition, enabled: true)
        referral.save!
      end
    end

    def wire_share_rules(rules)
      rules.each do |contact, document, condition|
        rule = ShareRule.find_or_initialize_by(contact: contact, document: document)
        rule.assign_attributes(condition: condition)
        rule.save!
      end
    end

    # A seeder's whole job is to tell you what it made and how to sign in.
    # standard:disable Rails/Output
    def report(case_study, student)
      reach = CaseReachability.new(case_study).call
      attached = Document.where(case_study_id: case_study.id).count { |d| d.file.attached? }

      puts "Seeded #{case_study.title}"
      puts "  join code: #{case_study.join_code}"
      puts "  author:    #{case_study.author.email}"
      puts "  student:   #{student.email}"
      puts "  password:  #{self.class.password}"
      puts "  cast:      #{case_study.contacts.count} (#{case_study.contacts.where(in_starting_directory: true).count} in the starting directory)"
      puts "  referrals: #{Referral.where(referring_contact_id: case_study.contacts.select(:id)).count}"
      puts "  documents: #{Document.where(case_study_id: case_study.id).count} (#{attached} with files)"
      puts "  reachable: #{reach.complete? ? "every contact" : "MISSING — #{reach.unreachable.map(&:full_name).to_sentence}"}"
    end
    # standard:enable Rails/Output
  end
end
