require 'active_support'

module Periods
  module Recurrable
    extend ActiveSupport::Concern
    included do

      validates_presence_of :end_date, :if => :end_date_required,
                                     :message => 'Please enter an end date, or indicate that there is no end date'
      validates_date :end_date, :after => lambda { Date.today }, :allow_blank => true,:after_message => "End date must be after today"

      scope :with_anniversary_on_today, lambda { where { next_billing_date <= Date.today } }

      before_save  :set_next_billing, :if => :end_date_changed?

      delegate :first_name, :to => :donor
      delegate :last_name, :to => :donor
      delegate :email, :to => :donor

      def self.active
        where do
          (status == 'active') &
          ((end_date == nil) | (end_date > Time.zone.now))
        end
      end

      def self.with_active_entity
        joins{ donor.entity }.where{ entities.status == Entity::ACTIVE_STATUS }
      end

      def self.non_pending
        where { status != 'pending' }
      end

      def self.active_for_today_as_anniversary_day
        active.with_active_entity.with_anniversary_on_today.uniq
      end

      def set_next_billing
        return unless active?
        self.next_billing_date = calculate_next_date({
          start_date: activated_at,
          period: period,
          end_date: end_date })
      end

      def process!(donor, orderable, add_or_deduct_fee)
        activate!(donor, orderable, add_or_deduct_fee)
        set_last_and_next_billing_dates
      end

      def set_last_and_next_billing_dates
        self.last_billing_date = Date.today
        self.attempt_count = 0
        set_next_billing
        self.save
      end

      def set_retry_details
        self.attempt_count += 1
        self.next_billing_date = Date.today + 3.days
      end

      def set_cancellation_details
        self.attempt_count += 1
        self.next_billing_date = nil
        self.status = 'failed'
      end

      def set_end_date(date)
        self.end_date = date
        self.no_end_date = false
        self.save!(:validate => false)
      end

      def activate!(donor, orderable, add_or_deduct_fee)
        return true if active?
        self.donor = donor
        self.status = 'active'
        self.add_or_deduct_fee = add_or_deduct_fee
        self.activated_at = Date.today
        self.save
        local_activate!(donor, orderable)
      end

      def pending?
        status == 'pending'
      end

      def completed?
        status == 'active' and ((end_date.present? && end_date < Date.today) )
      end

      def active?
        status == 'active' and !completed?
      end

      def inactive?
        status == 'stopped' || completed? || (status == 'failed' && attempt_count >= 3)
      end

      def failed?
        status == 'failed' && attempt_count < 3
      end

      def first_payment
        transactions.ordered.first
      end

      def has_active_payment?
        transactions.active.exists?
      end

      def has_recent_transaction?
        transactions.active.very_recent.present?
      end
      alias_method :has_recent_recurring_deposit_payment?, :has_recent_transaction?

      def image_url
        nil
      end

      def end_date_statement
        end_date.blank? ? 'with no end date' : "until #{end_date.to_s(:us)}"
      end

      def local_activate!(donor, orderable)
        # can be overridden by the module includer
      end

      def end_date_required
        false
      end
    end

  end
end