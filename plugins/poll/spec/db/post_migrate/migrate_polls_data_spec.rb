require 'rails_helper'
require_relative '../../../db/post_migrate/20180820080623_migrate_polls_data'

RSpec.describe MigratePollsData do
  describe 'for a regular poll' do
    let!(:user) { Fabricate(:user, id: 1) }
    let!(:user2) { Fabricate(:user, id: 2) }
    let!(:user3) { Fabricate(:user, id: 3) }
    let!(:user4) { Fabricate(:user, id: 4) }
    let!(:user5) { Fabricate(:user, id: 5) }
    let(:post) { Fabricate(:post, user: user) }

    before do
      post.custom_fields = {
        "polls" => {
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

    it 'should work' do
      expect do
        silence_stdout { MigratePollsData.new.up }
      end.to \
        change { Poll.count }.by(1) &
        change { PollOption.count }.by(2) &
        change { PollVote.count }.by(5)

      poll = Poll.last

      expect(poll.post_id).to eq(post.id)
      expect(poll.name).to eq("poll")
      expect(poll.close_at).to eq("2018-10-08T00:00:00.000Z")

      expect(Poll.pluck(:type, :status, :results, :visibility).first).to eq([
        Poll.types[:regular],
        Poll.statuses[:open],
        Poll.results[:always],
        Poll.visibilities[:everyone]
      ])

      expect(poll.min).to eq(nil)
      expect(poll.max).to eq(nil)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.all.to_a
      option_1 = poll_options.first

      expect(option_1.poll_id).to eq(poll.id)
      expect(option_1.digest).to eq("edeee5dae4802ab24185d41039efb545")
      expect(option_1.html).to eq("Yes")

      option_2 = poll_options.last

      expect(option_2.poll_id).to eq(poll.id)
      expect(option_2.digest).to eq("38d8e35c8fc80590f836f22189064835")
      expect(option_2.html).to eq("No")

      poll_votes = PollVote.all.to_a

      expect(poll_votes.map(&:poll_id).uniq).to eq([poll.id])

      [user, user2].each do |user|
        expect(PollVote.exists?(poll_option_id: option_1.id, user_id: user.id))
          .to eq(true)
      end

      [user3, user4, user5].each do |user|
        expect(PollVote.exists?(poll_option_id: option_2.id, user_id: user.id))
          .to eq(true)
      end
    end
  end
end
