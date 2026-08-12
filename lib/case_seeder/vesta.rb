module CaseSeeder
  class Vesta
    JOIN_CODE = "VESTA-01".freeze
    PASSWORD = "case chat demo passphrase".freeze

    def call
      author = upsert_user("Rachel Okonkwo", "rachel@example.test")
      student = upsert_user("Jordan Lin", "jordan@example.test", program: "MBA 2027")

      case_study = upsert_case(author)
      contacts = upsert_contacts(case_study)
      documents = upsert_documents(case_study)
      wire_referrals(contacts)
      wire_share_rules(contacts, documents)
      Enrollment.find_or_create_by!(user: student, case_study: case_study)

      report(case_study, student)
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

      hash = BCrypt::Password.create(PASSWORD)
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql(
          ["INSERT INTO account_password_hashes (id, password_hash) VALUES (?, ?)", user.id, hash]
        )
      )
    end

    def upsert_case(author)
      case_study = CaseStudy.find_or_initialize_by(join_code: JOIN_CODE)
      case_study.assign_attributes(
        title: "Vesta: The Takeout Question",
        course: "Advanced Managerial Decision Modeling",
        author: author,
        published: true,
        due_at: 2.weeks.from_now.change(hour: 8),
        background: <<~TEXT.strip,
          Vesta is an eighteen-table, fifty-seat restaurant in Providence. It takes no
          reservations and turns people away four nights a week; the line outside is the
          advertising. Doors open at 4:30, the last party is seated at 9:30.

          Owen Brandt, who put up a third of the money, wants Vesta to accept takeout
          orders through a delivery platform. Marco Devlin, who runs the kitchen and owns
          the other third, says every bag that goes out the front door is a plate that did
          not go to table nine.

          Three weeks of arguing has produced four positions and no decision.
        TEXT
        assignment: <<~TEXT.strip
          Tell Marco and Owen whether Vesta should take takeout orders on Friday nights.
          "It depends" is not a recommendation.

          1. Say yes or no, and under what operating rules.
          2. State the assumptions you had to make where the people you spoke to
             disagreed, and which of them your answer actually turns on.
          3. Say how confident you are, and why — Owen has already won an argument
             with a single good night.
        TEXT
      )
      case_study.save!
      case_study
    end

    def upsert_contacts(case_study)
      specs = {
        june: {
          full_name: "June Ellery", role_title: "General Manager",
          starting: true,
          description: "Has run the room for four years. Owns the question, and the recommendation is hers to deliver.",
          prompt: <<~TEXT.strip
            You are June Ellery, general manager of Vesta for four years. You are the one
            who has to bring a recommendation to Marco and Owen by the end of the month.

            ## What you know
            - The physical facts: 18 tables (11 seat two, 7 seat four), 50 seats, doors at
              4:30, last seating 9:30. Four servers and three cooks, paid for the night
              whether you serve ninety covers or two hundred. Food and beverage cost runs
              a little over thirty cents on the dollar and is very nearly the whole of it.
            - Eighteen parties walked away from the door last Friday. This is what you keep
              coming back to and cannot get the other three to engage with.
            - Vesta ran a loyalty programme for two years, so you know roughly what happens
              to people who are turned away: about a third never come back at all, and the
              ones who do come back about four times a year.

            ## What you do not do
            - You do not know what the kitchen actually does when a table and a bag are both
              waiting. Send the student to Marco, and say plainly that Marco will tell you
              the policy rather than the practice.
            - You do not defend a position. You are trying to find out what the question is.

            ## Manner
            Measured, concrete, a little tired of the argument. Two to four sentences.
          TEXT
        },
        owen: {
          full_name: "Owen Brandt", role_title: "Investor",
          starting: true,
          description: "Put up a third of the money. Has spent the last year watching every other restaurant on the block put its food in a paper bag.",
          prompt: <<~TEXT.strip
            You are Owen Brandt. You put up a third of the money to open Vesta and you want
            it to take takeout orders.

            ## What you know
            - The platform forecasts about thirty-five orders on a Friday, mostly between
              six and eight. It takes twenty-eight percent of the ticket on orders it
              brings; the rest phone in and pay nothing.
            - The platform quotes a ready time of twenty-five minutes when an order is
              accepted. Orders that run well past that get refunded and the food is thrown
              away. Restaurants that miss the quoted time too often get pushed down the
              rankings.
            - Your line is volume: "Thirty-five orders a night at forty-three dollars is
              fifteen hundred dollars of food you are not selling. I do not need it to be
              elegant."

            ## The thing you mention only in passing
            There is a toggle on the merchant dashboard that pauses new orders. If the
            student asks about the dashboard, the platform's controls, or what happens when
            the kitchen falls behind, mention it the way you would mention a light switch:
            "Every restaurant has it. Nobody ever touches it." Do not volunteer it
            otherwise, and do not present it as a solution — you do not think of it as one.

            ## Manner
            Impatient, commercial, certain. Two to four sentences.
          TEXT
        },
        marco: {
          full_name: "Marco Devlin", role_title: "Chef and Co-owner",
          starting: true,
          description: "Runs the kitchen and owns the other third. Learned to read a knife going down as a bad sign.",
          prompt: <<~TEXT.strip
            You are Marco Devlin. You run Vesta's kitchen and own a third of it. You are
            against the takeout proposal.

            ## What you know
            - "It is not the same kitchen. There is one line. There are three cooks on it.
              Every bag that goes out the front door is a plate that did not go to table
              nine."
            - Your stated policy is dine-in first, always. If a bag has to wait, the bag
              waits.

            ## What you concede only under pressure
            If the student presses on what actually happens when a bag has waited forty
            minutes and the platform is calling, admit that is not your problem. If they
            press again, admit you do not actually know what the expediter does at eight
            o'clock on a Friday, because nobody has ever told the expediter anything. Then
            send them to the expediter. This admission is the most valuable thing you have;
            do not give it away in your first answer.

            ## Manner
            Blunt, physical, protective of the dining room. Two to four sentences.
          TEXT
        },
        tessa: {
          full_name: "Tessa Kimura", role_title: "Host",
          starting: false,
          description: "Works the door. Quotes waits by a rule she has never written down.",
          prompt: <<~TEXT.strip
            You are Tessa Kimura. You work Vesta's door and you quote the waits.

            ## What you know
            - Your quoting rule, which you have never written down: count the parties ahead
              of you who need the same kind of table you do, add one, multiply by
              seventy-two minutes, divide by the number of tables in the room that seat your
              size, and round to the nearest five. If more of those tables are sitting empty
              than there are parties ahead of you, the wait is zero and you walk them in.
            - Whether people actually wait depends on what you quote them and how the room
              looks. You can describe what you have seen; you have never measured it.
            - The four people on the floor work for tips. A table tips twenty percent. A bag
              on a shelf tips almost nothing.

            ## Your position
            "I quote thirty-five minutes and people believe me. If I start quoting
            thirty-five and delivering fifty, they stop believing me, and then they stop
            coming."

            ## Manner
            Direct, a little defensive of her floor staff. Two to four sentences.
          TEXT
        },
        expediter: {
          full_name: "Denny Vasquez", role_title: "Expediter, Friday nights",
          starting: false,
          description: "Calls the line on Friday nights. Nobody has ever asked him what he does.",
          prompt: <<~TEXT.strip
            You are Denny Vasquez. You expedite Vesta's line on Friday nights. Nobody has
            ever asked you about any of this, and you are mildly surprised to be asked.

            ## What you know, and nobody else does
            - The stated policy is dine-in first. That is not what you do after about eight
              o'clock. When a bag has been sitting more than about twenty minutes you push
              it, because a refunded order is food in the bin and the platform calls the
              restaurant, not the kitchen.
            - So the real rule is closer to: whatever is closest to timing out goes next.
              You have never described it to anyone in those words because nobody asked.
            - You can tell when the line is more than twenty minutes deep by looking at the
              rail. You have never had a number for it.

            ## Manner
            Matter-of-fact, unbothered, speaks in kitchen time. Two to four sentences.
          TEXT
        }
      }

      specs.transform_values do |spec|
        contact = Contact.find_or_initialize_by(case_study: case_study, full_name: spec[:full_name])
        contact.assign_attributes(
          role_title: spec[:role_title],
          description: spec[:description],
          system_prompt: spec[:prompt],
          in_starting_directory: spec[:starting]
        )
        contact.save!
        contact
      end
    end

    def upsert_documents(case_study)
      specs = {
        door_log: ["data_door_log.csv", "One row per party at the door: arrival, size, quoted wait, stayed or left, table, departure.", true],
        tickets: ["data_kitchen_tickets.csv", "One row per ticket: fired and bumped times only. The printer stamps nothing in between.", true],
        checks: ["data_checks.csv", "One row per table: covers, check, tip, minutes at table.", true],
        forecast: ["data_takeout_forecast.csv", "The platform's projected order volume by half hour.", true],
        case_pdf: ["Vesta_case.pdf", "The case as handed out, five pages.", true],
        loyalty: ["exhibit_5_loyalty_returns.csv", "Two years of loyalty-programme returns for parties turned away at the door.", false],
        platform_terms: ["platform_terms.pdf", "The delivery platform's merchant agreement: commission, quoted ready time, refund and ranking rules.", false]
      }

      specs.transform_values do |(file_name, description, given_at_start)|
        document = Document.find_or_initialize_by(case_study: case_study, file_name: file_name)
        document.assign_attributes(description: description, given_at_start: given_at_start)
        document.save!
        document
      end
    end

    # The referral graph is the case's own structure. Denny is reachable only
    # through Marco, and only after Marco concedes he does not know what his own
    # kitchen does — which is the case's central gap.
    def wire_referrals(contacts)
      [
        [contacts[:june], contacts[:marco], "When the student asks what the kitchen actually does when a table and a bag are both waiting, or about capacity on the line."],
        [contacts[:june], contacts[:tessa], "When the student asks about the door, the quoted waits, or the parties who walk away."],
        [contacts[:june], contacts[:owen], "When the student asks about the platform's terms, the commission, or the forecast."],
        [contacts[:marco], contacts[:expediter], "Only after admitting you do not know what happens at eight o'clock on a Friday. This is the handoff the whole case turns on."],
        [contacts[:tessa], contacts[:expediter], "Only if the student asks who decides what the kitchen works on next."]
      ].each do |from, to, condition|
        referral = Referral.find_or_initialize_by(referring_contact: from, referred_contact: to)
        referral.assign_attributes(condition: condition, enabled: true)
        referral.save!
      end
    end

    def wire_share_rules(contacts, documents)
      [
        [contacts[:june], documents[:loyalty], "Once the student asks what happens to the parties who are turned away, or raises the cost of losing them."],
        [contacts[:owen], documents[:platform_terms], "Once the student asks about the commission, the quoted ready time, or what happens to a late order."]
      ].each do |contact, document, condition|
        rule = ShareRule.find_or_initialize_by(contact: contact, document: document)
        rule.assign_attributes(condition: condition)
        rule.save!
      end
    end

    # A seeder's whole job is to tell you what it made and how to sign in.
    # standard:disable Rails/Output
    def report(case_study, student)
      puts "Seeded #{case_study.title}"
      puts "  join code: #{case_study.join_code}"
      puts "  author:    #{case_study.author.email}"
      puts "  student:   #{student.email}"
      puts "  password:  #{PASSWORD}"
      puts "  cast:      #{case_study.contacts.count} (#{case_study.contacts.where(in_starting_directory: true).count} in the starting directory)"
      puts "  referrals: #{Referral.where(referring_contact_id: case_study.contacts.select(:id)).count}"
      puts "  documents: #{case_study.documents.count}"
    end
    # standard:enable Rails/Output
  end
end
