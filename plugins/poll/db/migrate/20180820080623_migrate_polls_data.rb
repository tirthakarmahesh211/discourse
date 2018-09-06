class MigratePollsData < ActiveRecord::Migration[5.2]
  def escape(text)
    PG::Connection.escape_string(text)
  end

  def up
    sql = <<~SQL
      SELECT polls.post_id
           , polls.created_at
           , polls.updated_at
           , polls.value::json "polls"
           , votes.value::json "votes"
        FROM post_custom_fields polls
        JOIN post_custom_fields votes
          ON polls.post_id = votes.post_id
       WHERE polls.name = 'polls'
         AND votes.name = 'polls-votes'
       ORDER BY polls.post_id
    SQL

    DB.query(sql).each do |r|
      begin
        existing_user_ids = User.where(id: r.votes.keys).pluck(:id).to_set

        # Poll votes are stored in a JSON object with the following hierarchy
        #   user_id -> poll_name -> options
        # Since we're iterating over polls, we need to change the hierarchy to
        #   poll_name -> user_id -> options

        votes = {}
        r.votes.each do |user_id, user_votes|
          # don't migrate votes from deleted/non-existing users
          next unless existing_user_ids.include?(user_id.to_i)

          user_votes.each do |poll_name, options|
            votes[poll_name] ||= {}
            votes[poll_name][user_id] = options
          end
        end

        r.polls.values.each do |poll|
          name = poll["name"].presence || "poll"
          type = (poll["type"].presence || "")[/(regular|multiple|number)/, 1] || "regular"
          status = poll["status"] == "open" ? "open" : "closed"
          visibility = poll["public"] == "t" ? "public" : "private"
          close_at = (Time.zone.parse(poll["close"]) rescue nil)
          min = poll["min"].to_i
          max = poll["max"].to_i
          step = poll["step"].to_i

          poll_id = execute(<<~SQL
            INSERT INTO polls (
              post_id,
              name,
              type,
              status,
              visibility,
              close_at,
              min,
              max,
              step,
              created_at,
              updated_at
            ) VALUES (
              #{r.post_id},
              '#{escape(name)}',
              '#{escape(type)}',
              '#{escape(status)}',
              '#{escape(visibility)}',
              #{close_at ? "'#{close_at}'" : "NULL"},
              #{min > 0 ? min : "NULL"},
              #{max > min ? max : "NULL"},
              #{step > 0 ? step : "NULL"},
              '#{r.created_at}',
              '#{r.updated_at}'
            ) RETURNING id
          SQL
          )[0]["id"]

          option_ids = Hash[*DB.query_single(<<~SQL
            INSERT INTO poll_options
              (poll_id, digest, html, created_at, updated_at)
            VALUES
              #{poll["options"].map { |option| "(#{poll_id}, '#{escape(option["id"])}', '#{escape(option["html"].strip)}', '#{r.created_at}', '#{r.updated_at}')" }.join(",")}
            RETURNING digest, id
          SQL
          )]

          if votes[name].present?
            execute <<~SQL
              INSERT INTO poll_votes
                (poll_id, poll_option_id, user_id, created_at, updated_at)
              VALUES
                #{votes[name]
                    .map do |user_id, options|
                      options
                        .select { |o| option_ids.has_key?(o) }
                        .map { |o| "(#{poll_id}, #{option_ids[o]}, #{user_id.to_i}, '#{r.created_at}', '#{r.updated_at}')" }
                    end.flatten.join(",")
                }
            SQL
          end
        end
      rescue
        Rails.logger.warn "Could not migrate polls for post ##{r.post_id}"
      end
    end

    execute <<~SQL
      INSERT INTO post_custom_fields (name, value, post_id, created_at, updated_at)
      SELECT 'has_polls', 't', post_id, MIN(created_at), MIN(updated_at)
        FROM polls
       GROUP BY post_id
    SQL
  end

  def down
  end
end
