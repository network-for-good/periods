require 'spec_helper'

require 'periods/calculator'
require 'date'

RSpec.describe Periods::Calculator do

  class TestDummy
    include Periods::Calculator
  end

  let(:test_dummy) { TestDummy.new }

  subject { test_dummy.advance(date, options ) }
  let(:date) { Date.new(2013,1,31) }

  describe "#advance" do
    context "when passed a monthly option" do
      let(:options) { { monthly: 5} }
      it "should return the date advanced by the amount of months" do
        expect(subject).to eql(Date.new(2013,6,30))
      end
    end

    context "when passed a quarterly option" do
      let(:date) { Date.new(2012,2,29) }
      let(:options) { { quarterly: 4} }

      it "should return the date advanced by the amount of quarters" do
        expect(subject).to eql(Date.new(2013,2,28))
      end
    end

    context "when passed a annually option" do
      let(:date) { Date.new(2012,2,07) }
      let(:options) { { annually: 3} }

      it "should return the date advanced by the amount of years" do
        expect(subject).to eql(Date.new(2015,2,7))
      end
    end

    context "when passed a semi_annually option" do
      let(:date) { Date.new(2012,2,07) }
      let(:options) { { semi_annually: 3} }

      it "should return the date advanced by the amount of years" do
        expect(subject).to eql(Date.new(2013,8,7))
      end
    end

    context "when passed a weekly option" do
      let(:date) { Date.new(2012,2,13) }
      let(:options) { { weekly: 4} }

      it "should return the date advanced by the amount of weeks" do
        expect(subject).to eql(Date.new(2012,3,12))
      end
    end

    context "when passed a daily option" do
      let(:date) { Date.new(2012,2,13) }
      let(:options) { { daily: 4} }

      it "should return the date advanced by the amount of days" do
        expect(subject).to eql(Date.new(2012,2,17))
      end
    end
  end

  describe "#calculate_next_date" do
    before(:each) do
      Timecop.freeze(Date.new(2012,1,31))
    end
    let(:options) { nil }
    subject { test_dummy.calculate_next_date(options) }

    context "when passed no options" do
      subject { test_dummy.calculate_next_date }
      it "should return one month from today" do
        expect(subject).to eql(Date.new(2012,2,29))
      end
    end

    context "when passed a start date" do
      let(:options) { { start_date: Date.new(2011,12,17) } }
      it "should advance to the first monthly anniversary of the start date after today" do
        expect(subject).to eql(Date.new(2012,2,17))
      end
    end

    context "when passed a period type (weekly, quarterly, annually, daily, semi_annually)" do
      periods = { weekly: Date.new(2012,2,7), quarterly: Date.new(2012,2,17), annually: Date.new(2012,5,17), daily: Date.new(2012,2,1), semi_annually: Date.new(2012,5,17) }
      periods.each do |period, expected_date|
        it "should advance to the first anniversary of the period after today's date. For #{period}, should be #{ expected_date }" do
          expect(test_dummy.calculate_next_date(start_date: Date.new(2011,5,17), period: period)).to eql(expected_date)
        end
      end

    end

    context "when passed a invalid period type" do
      let(:options) { { start_date: Date.new(2011,5,17), period: :fortnight } }
      it { expect { subject }.to raise_error(ArgumentError) }
    end

    context "when passed an end date" do
      let(:options) { { start_date: Date.new(2011,5,17),
                        period: :quarterly,
                        end_date: Date.new(2012,7,30)
                        } }
      context "and the date to be advanced to is before the end date" do
        it "should return the date to be advanced to" do
          expect(subject).to eql(Date.new(2012,2,17))
        end
      end

      context "and the date to be advanced is same as the end date" do
        let(:options) { { start_date: Date.new(2011,12,17),
                        period: :monthly,
                        end_date: Date.new(2012,2,17)
                        } }
        it "should return the date to be advanced to" do
          expect(subject).to eql(Date.new(2012,2,17))
        end
      end

      context "and the end date is before the date to be advanced to" do
        let(:options) { { start_date: Date.new(2011,5,17),
                          period: :quarterly,
                          end_date: Date.new(2012,1,30)
                          } }
        it "should return nil" do
          expect(subject).to_not be
        end
      end
    end

    describe "#calculate_no_of_periods" do

      before(:each) do
        Timecop.freeze(Date.new(2012,1,31))
      end
      let(:start_date) { Date.new(2011,5,17) }
      let(:period) { :monthly }
      let(:end_date) { Date.new(2012,1,30) }

      subject { test_dummy.calculate_no_of_periods(start_date, end_date, period) }

      context "#date" do
        it "should return the date advanced by the amount of months" do
          expect(subject[:date]).to eq Date.new(2012,02,17)
        end
      end

      context "#count" do
        it "should return the number of counts advanced by the amount of months" do
          expect(subject[:count]).to eq 9
        end
      end
    end

    describe "#calculate_total_value" do

      before(:each) do
        Timecop.freeze(Date.new(2012,1,31))
      end

      let(:recurring_donation) {
        OpenStruct.new( end_date: end_date , total_amount_per_period: total_amount_per_period , period: period )
      }
      let(:end_date) { Date.new(2012,7,30)  }
      let(:period) { 'monthly' }
      let(:total_amount_per_period) { 10 }

      subject { test_dummy.calculate_total_value(recurring_donation) }

      context "#end_date" do
        context "when there is no recurring_donation end date" do
          let(:end_date) { nil }

          it "should default to 1 year minus 1 day from now" do
            expect(subject[:end_date]).to eq Date.new(2013,1,30)
          end
        end

        context "when there is recurring_donation end date" do

          it "should return recurring_donation end date" do
            expect(subject[:end_date]).to eq end_date
          end
        end
      end

      context "#total_amount" do

        it "should return the total_amount paid till the end_date" do
          expect(subject[:total_amount]).to eq (total_amount_per_period * subject[:no_of_periods])
        end
      end

      context "#no_of_periods" do

        it "should return the total payment frequency + 1 till the end_date" do
          expect(subject[:no_of_periods]).to eq 6
        end
      end
    end
  end
end