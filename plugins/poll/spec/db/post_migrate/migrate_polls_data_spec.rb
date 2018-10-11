require 'rails_helper'
require_relative '../../../db/post_migrate/20180820080623_migrate_polls_data'

RSpec.describe MigratePollsData do
  let!(:user) { Fabricate(:user, id: 1) }
  let!(:user2) { Fabricate(:user, id: 2) }
  let!(:user3) { Fabricate(:user, id: 3) }
  let!(:user4) { Fabricate(:user, id: 4) }
  let!(:user5) { Fabricate(:user, id: 5) }
  let(:post) { Fabricate(:post, user: user) }

  describe 'for a multiple poll' do
    before do
      post.custom_fields = {
        "polls-votes" => {
          "1" => {
            "testing" => [
              "b2c3e3668a886d09e97e38b8adde7d45",
              "28df49fa9e9c09d3a1eb8cfbcdcda7790",
            ]
          },
          "2" => {
            "testing" => [
              "b2c3e3668a886d09e97e38b8adde7d45",
              "d01af008ec373e948c0ab3ad61009f35",
            ]
          },
        },
        "polls" => {
          "poll" => {
            "options" => [
              {
                "id" => "b2c3e3668a886d09e97e38b8adde7d45",
                "html" => "Choice 1",
                "votes" => 2,
                "voter_ids" => [user.id, user2.id]
              },
              {
                "id" => "28df49fa9e9c09d3a1eb8cfbcdcda7790",
                "html" => "Choice 2",
                "votes" => 1,
                "voter_ids" => [user.id]
              },
              {
                "id" => "d01af008ec373e948c0ab3ad61009f35",
                "html" => "Choice 3",
                "votes" => 1,
                "voter_ids" => [user2.id]
              },
            ],
            "voters" => 4,
            "name" => "testing",
            "status" => "closed",
            "type" => "multiple",
            "public" => "true"
          }
        }
      }

      post.save_custom_fields
    end

    it 'should migrate the data properly' do
      expect do
        silence_stdout { MigratePollsData.new.up }
      end.to \
        change { Poll.count }.by(1) &
        change { PollOption.count }.by(3) &
        change { PollVote.count }.by(4)

      poll = Poll.last

      expect(poll.post_id).to eq(post.id)
      expect(poll.name).to eq("testing")
      expect(poll.close_at).to eq(nil)

      expect(Poll.pluck(:type, :status, :results, :visibility).first).to eq([
        Poll.types[:multiple],
        Poll.statuses[:closed],
        Poll.results[:always],
        Poll.visibilities[:everyone]
      ])

      expect(poll.min).to eq(nil)
      expect(poll.max).to eq(nil)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.all

      poll_option_1 = poll_options[0]
      expect(poll_option_1.poll_id).to eq(poll.id)
      expect(poll_option_1.digest).to eq("b2c3e3668a886d09e97e38b8adde7d45")
      expect(poll_option_1.html).to eq("Choice 1")

      poll_option_2 = poll_options[1]
      expect(poll_option_2.poll_id).to eq(poll.id)
      expect(poll_option_2.digest).to eq("28df49fa9e9c09d3a1eb8cfbcdcda7790")
      expect(poll_option_2.html).to eq("Choice 2")

      poll_option_3 = poll_options[2]
      expect(poll_option_3.poll_id).to eq(poll.id)
      expect(poll_option_3.digest).to eq("d01af008ec373e948c0ab3ad61009f35")
      expect(poll_option_3.html).to eq("Choice 3")

      expect(PollVote.all.pluck(:poll_id).uniq).to eq([poll.id])

      {
        user => [poll_option_1, poll_option_2],
        user2 => [poll_option_1, poll_option_3]
      }.each do |user, options|
        options.each do |option|
          expect(PollVote.exists?(poll_option_id: option.id, user_id: user.id))
            .to eq(true)
        end
      end
    end
  end

  describe 'for a regular poll' do
    before do
      post.custom_fields = {
        "polls" => {
          "testing" => {
            "options" => [
              {
                "id" => "e94c09aae2aa071610212a5c5042111b",
                "html" => "Yes",
                "votes" => 0,
                "voter_ids" => []
              },
              {
                "id" => "802c50392a68e426d4b26d81ddc5ab33",
                "html" => "No",
                "votes" => 0,
                "voter_ids" => []
              }
            ],
            "voters" => 0,
            "name" => "testing",
            "status" => "open",
            "type" => "regular"
          },
          "poll" => {
            "options" =>  [
              {
                "id" => "edeee5dae4802ab24185d41039efb545",
                "html" => "Yes",
                "votes" => 2,
                "voter_ids" => [1, 2]
              },
              {
                "id" => "38d8e35c8fc80590f836f22189064835",
                "html" =>
                "No",
                "votes" => 3,
                "voter_ids" => [3, 4, 5]
              }
            ],
            "voters" => 5,
            "name" => "poll",
            "status" => "open",
            "type" => "regular",
            "public" => "true",
            "close" => "2018-10-08T00:00:00.000Z"
          },
        },
        "polls-votes" => {
          "1" => { "poll" => ["edeee5dae4802ab24185d41039efb545"] },
          "2" => { "poll" => ["edeee5dae4802ab24185d41039efb545"] },
          "3" => { "poll" => ["38d8e35c8fc80590f836f22189064835"] },
          "4" => { "poll" => ["38d8e35c8fc80590f836f22189064835"] },
          "5" => { "poll" => ["38d8e35c8fc80590f836f22189064835"] }
        }
      }

      post.save_custom_fields
    end

    it 'should migrate the data properly' do
      expect do
        silence_stdout { MigratePollsData.new.up }
      end.to \
        change { Poll.count }.by(2) &
        change { PollOption.count }.by(4) &
        change { PollVote.count }.by(5)

      poll = Poll.find_by(name: "poll")

      expect(poll.post_id).to eq(post.id)
      expect(poll.close_at).to eq("2018-10-08T00:00:00.000Z")

      expect(
        Poll.where(name: "poll").pluck(
          :type,
          :status,
          :results,
          :visibility
        ).first
      ).to eq([
        Poll.types[:regular],
        Poll.statuses[:open],
        Poll.results[:always],
        Poll.visibilities[:everyone]
      ])

      expect(poll.min).to eq(nil)
      expect(poll.max).to eq(nil)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.where(poll_id: poll.id).to_a
      expect(poll_options.size).to eq(2)

      option_1 = poll_options.first
      expect(option_1.digest).to eq("edeee5dae4802ab24185d41039efb545")
      expect(option_1.html).to eq("Yes")

      option_2 = poll_options.last
      expect(option_2.digest).to eq("38d8e35c8fc80590f836f22189064835")
      expect(option_2.html).to eq("No")

      expect(PollVote.pluck(:poll_id).uniq).to eq([poll.id])

      [user, user2].each do |user|
        expect(PollVote.exists?(poll_option_id: option_1.id, user_id: user.id))
          .to eq(true)
      end

      [user3, user4, user5].each do |user|
        expect(PollVote.exists?(poll_option_id: option_2.id, user_id: user.id))
          .to eq(true)
      end

      poll = Poll.find_by(name: "testing")

      expect(poll.post_id).to eq(post.id)
      expect(poll.close_at).to eq(nil)

      expect(
        Poll.where(name: "testing").pluck(
          :type,
          :status,
          :results,
          :visibility
        ).first
      ).to eq([
        Poll.types[:regular],
        Poll.statuses[:open],
        Poll.results[:always],
        Poll.visibilities[:secret]
      ])

      expect(poll.min).to eq(nil)
      expect(poll.max).to eq(nil)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.where(poll: poll).to_a
      expect(poll_options.size).to eq(2)

      option_1 = poll_options.first
      expect(option_1.digest).to eq("e94c09aae2aa071610212a5c5042111b")
      expect(option_1.html).to eq("Yes")

      option_2 = poll_options.last
      expect(option_2.digest).to eq("802c50392a68e426d4b26d81ddc5ab33")
      expect(option_2.html).to eq("No")
    end
  end
end
