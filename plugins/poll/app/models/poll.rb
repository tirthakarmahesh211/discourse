class Poll < ActiveRecord::Base
  # because we want to use the 'type' column and don't want to use STI
  self.inheritance_column = nil

  belongs_to :post

  has_many :poll_options, dependent: :destroy
  has_many :poll_votes

  enum type: {
    regular: 0,
    multiple: 1,
    number: 2,
  }

  enum status: {
    open: 0,
    closed: 1,
  }

  enum results: {
    always: 0,
    on_vote: 1,
    on_close: 2,
  }

  enum visibility: {
    secret: 0,
    everyone: 1,
  }

  validates :min, numericality: { allow_nil: true, only_integer: true, greater_than: 0 }
  validates :max, numericality: { allow_nil: true, only_integer: true, greater_than: 0 }
  validates :step, numericality: { allow_nil: true, only_integer: true, greater_than: 0 }

  def is_closed?
    closed? || (close_at && close_at <= Time.zone.now)
  end

  def can_see_results?(user)
    always? || is_closed? || (on_vote? && has_voted?(user))
  end

  def has_voted?(user)
    user&.id && poll_votes.any? { |v| v.user_id == user.id }
  end

  def can_see_voters?(user)
    everyone? && can_see_results?(user)
  end
end
