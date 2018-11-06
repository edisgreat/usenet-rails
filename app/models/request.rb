class Request < ApplicationRecord
  has_many :results
  validate :check_dates
  validate :check_strings
  before_create :set_defaults
  after_create :create_results

  def check_dates
    if(start_date < '1981-01-01'.to_date)
      errors.add(:start_date, "Cannot be before 1981")
    end
    if(end_date > '2000-01-01'.to_date)
      errors.add(:end_date, "Cannot be after 2000")
    end
    if(end_date <= start_date)
      errors.add(:end_date, "Must be after Start Date")
    end
  end

  def check_strings
    if query.blank?
      errors.add(:query, "Cannot be empty")
    end
    if cookie.blank?
      errors.add(:cookie, "Cannot be empty")
    end
    if authstring.blank?
      errors.add(:authstring, "Cannot be empty")
    end
    if author_email.blank?
      errors.add(:author_email, "Cannot be empty")
    end
    if author_name.blank?
      errors.add(:author_name, "Cannot be empty")
    end
  end

  def set_defaults
    status = 0
    source = 'google_groups'
  end

  def create_results
    # Make monthly results
    loop_start_date = start_date.at_beginning_of_month #ensure no cheats
    loop_end_date = end_date.at_beginning_of_month

    while loop_start_date < loop_end_date
      result_start_date = loop_start_date
      result_end_date = loop_start_date.next_month
      
      results.create(start_date: result_start_date, end_date: result_end_date, amount: 0, precision: 'month', status: 0)

      loop_start_date = result_end_date
    end
  end
end