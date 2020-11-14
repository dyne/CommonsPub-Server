# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Repo.Migrations.BigRefactor do
  use Ecto.Migration
  alias CommonsPub.Repo
  alias Ecto.ULID
  import Pointers.Migration

  @meta_tables [] ++
                 ~w(mn_feed mn_country mn_language mn_peer mn_user mn_community) ++
                 ~w(mn_collection mn_resource mn_activity mn_thread mn_comment) ++
                 ~w(mn_like mn_flag mn_follow mn_feature mn_block) ++
                 ~w(mn_access_register_email mn_access_register_email_domain)

  # @languages [
  #   {"en", "eng", "English", "English"}
  # ]
  # @tag_categories ["Hashtag", "K-12 Classification"]
  # @countries [
  #   {"nl", "nld", "Netherlands", "Nederland"}
  # ]

  def up do
    ### meta system ###

    ## database tables participating in the 'meta' abstraction
    # only updated during migrations!
    # create table(:pointers_table) do
    #   add(:table, :text, null: false)
    # end

    # create(unique_index(:pointers_table, :table))

    ## a pointer to an entry in any table participating in the meta abstraction
    # create table(:mn_pointer) do
    #   add(:table_id, references("pointers_table", on_delete: :restrict), null: false)
    # end

    # create(index(:mn_pointer, :table_id))

    # basically a reservation
    create table(:mn_feed) do
    end

    create table(:mn_feed_subscription) do
      add(
        :subscriber_id,
        strong_pointer()
      )

      add(:feed_id, references("mn_feed", on_delete: :delete_all), null: false)
      add(:activated_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(
      unique_index(
        :mn_feed_subscription,
        [:subscriber_id, :feed_id],
        name: :mn_feed_subscription_subscriber_feed_idx,
        where: "deleted_at is null"
      )
    )

    create(index(:mn_feed_subscription, :subscriber_id))
    create(index(:mn_feed_subscription, :feed_id))

    # countries

    create table(:mn_country) do
      add(:iso_code2, :string, size: 2)
      add(:iso_code3, :string, size: 3)
      add(:english_name, :text, null: false)
      add(:local_name, :text, null: false)
      add(:deleted_at, :timestamptz)
      add(:published_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_country, :iso_code2))
    create(unique_index(:mn_country, :iso_code3))

    # languages

    create table(:mn_language) do
      add(:iso_code2, :string, size: 2)
      add(:iso_code3, :string, size: 3)
      add(:english_name, :text, null: false)
      add(:local_name, :text, null: false)
      add(:deleted_at, :timestamptz)
      add(:published_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_language, :iso_code2))
    create(unique_index(:mn_language, :iso_code3))

    # access control

    create table(:mn_access_register_email_domain) do
      add(:domain, :text, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_access_register_email_domain, :domain))

    create table(:mn_access_register_email) do
      add(:email, :text, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_access_register_email, :email))

    ### activitypub system

    # an activitypub-compatible peer instance
    create table(:mn_peer) do
      add(:ap_url_base, :text, null: false)
      # shown in the username of actors
      add(:domain, :text, null: false)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_peer, :ap_url_base, where: "deleted_at is null"))
    create(unique_index(:mn_peer, :domain, where: "deleted_at is null"))

    ### actor system

    # basically a reservation table for unique ids plus activitypub stuff
    # currently linked to a user, community or collection
    create table(:mn_actor) do
      # null for local
      add(:peer_id, references("mn_peer", on_delete: :delete_all))
      add(:preferred_username, :text, null: false)
      add(:canonical_url, :text)
      add(:signing_key, :text)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(
      unique_index(
        :mn_actor,
        [:preferred_username, :peer_id],
        name: :mn_actor_preferred_username_peer_id_index
      )
    )

    create(
      unique_index(
        :mn_actor,
        [:preferred_username],
        where: "peer_id is null",
        name: :mn_actor_peer_id_null_index
      )
    )

    ### user system

    # a user that signed up on our instance

    create table(:mn_local_user) do
      add(:email, :text, null: false)
      add(:password_hash, :text, null: false)
      add(:confirmed_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:wants_email_digest, :boolean, null: false, default: false)
      add(:wants_notifications, :boolean, null: false, default: false)
      add(:is_instance_admin, :boolean, null: false, default: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_local_user, :email, where: "deleted_at is null"))

    # any user, including remote ones

    create table(:mn_user) do
      add(:actor_id, references("mn_actor", on_delete: :delete_all))
      add(:local_user_id, references("mn_local_user", on_delete: :nilify_all))
      add(:primary_language_id, references("mn_language", on_delete: :nilify_all))
      add(:inbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:outbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:name, :text)
      add(:summary, :text)
      add(:location, :text)
      add(:website, :text)
      add(:icon, :text)
      add(:image, :text)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_user, :actor_id))
    create(unique_index(:mn_user, :local_user_id))
    create(unique_index(:mn_user, :primary_language_id))

    # a storage for time-limited email confirmation tokens
    create table(:mn_local_user_email_confirm_token) do
      add(:local_user_id, references("mn_local_user", on_delete: :delete_all), null: false)
      add(:expires_at, :timestamptz, null: false)
      add(:confirmed_at, :timestamptz)
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create(index(:mn_local_user_email_confirm_token, :local_user_id))

    create table(:mn_local_user_reset_password_token) do
      add(:local_user_id, references("mn_local_user", on_delete: :delete_all), null: false)
      add(:expires_at, :timestamptz, null: false)
      add(:reset_at, :timestamptz)
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create(index(:mn_local_user_reset_password_token, :local_user_id))

    # a community is a group actor that is home to collections,
    # threads and members
    create table(:mn_community) do
      add(:actor_id, references(:mn_actor, on_delete: :delete_all))
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:primary_language_id, references("mn_language", on_delete: :nilify_all))
      add(:inbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:outbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:name, :text)
      add(:summary, :text)
      add(:icon, :text)
      add(:image, :text)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_community, :updated_at))
    create(index(:mn_community, :creator_id))
    create(index(:mn_community, :actor_id))
    create(index(:mn_community, :primary_language_id))

    # a collection is a group actor that is home to resources
    create table(:mn_collection) do
      add(:actor_id, references("mn_actor", on_delete: :delete_all))
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:community_id, references("mn_community", on_delete: :nilify_all))
      add(:primary_language_id, references("mn_language", on_delete: :nilify_all))
      add(:inbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:outbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:name, :text)
      add(:summary, :text)
      add(:icon, :text)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_collection, :updated_at))
    create(index(:mn_collection, :actor_id))
    create(index(:mn_collection, :creator_id))
    create(index(:mn_collection, :community_id))
    create(index(:mn_collection, :primary_language_id))

    # a resource is an item in a collection, a link somewhere or some text

    create table(:mn_resource) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      # add(:collection_id, references("mn_collection", on_delete: :nilify_all))
      add(:primary_language_id, references("mn_language", on_delete: :nilify_all))
      add(:name, :string)
      add(:summary, :text)
      add(:url, :string)
      add(:license, :string)
      add(:icon, :string)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_resource, :updated_at))
    create(unique_index(:mn_resource, :canonical_url))
    create(index(:mn_resource, :creator_id))
    # create(index(:mn_resource, :collection_id))
    create(index(:mn_resource, :primary_language_id))

    ### comment system

    create table(:mn_thread) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true)
      add(:outbox_id, references("mn_feed", on_delete: :nilify_all))
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:locked_at, :timestamptz)
      add(:hidden_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_thread, :updated_at))
    create(unique_index(:mn_thread, :canonical_url))
    create(index(:mn_thread, :creator_id))
    create(index(:mn_thread, :context_id))

    create table(:mn_comment) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:thread_id, references("mn_thread", on_delete: :delete_all), null: false)
      add(:reply_to_id, references("mn_comment", on_delete: :nilify_all))
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:hidden_at, :timestamptz)
      add(:content, :text)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_comment, :updated_at))
    create(unique_index(:mn_comment, :canonical_url))
    create(index(:mn_comment, :creator_id))
    create(index(:mn_comment, :thread_id))

    create table(:mn_follow) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true)
      add(:muted_at, :timestamptz)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_follow, :updated_at))
    create(unique_index(:mn_follow, :canonical_url))
    create(unique_index(:mn_follow, [:creator_id, :context_id], where: "deleted_at is null"))
    create(index(:mn_follow, :context_id))

    create table(:mn_like) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_like, :updated_at))
    create(unique_index(:mn_like, :canonical_url))
    create(unique_index(:mn_like, [:creator_id, :context_id], where: "deleted_at is null"))
    create(index(:mn_like, :context_id))

    # a flagged piece of content. may be a user, community,
    # collection, resource, thread, comment
    create table(:mn_flag) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true)
      add(:community_id, references("mn_community", on_delete: :nilify_all))
      add(:message, :text, null: false)
      add(:resolved_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_flag, :updated_at))
    create(unique_index(:mn_flag, :canonical_url))
    create(unique_index(:mn_flag, [:creator_id, :context_id], where: "deleted_at is null"))
    create(index(:mn_flag, :context_id))
    create(index(:mn_flag, :community_id))

    ### blocking system

    create table(:mn_block) do
      add(:canonical_url, :text)
      # always the person that created it
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      # if this is set, it's a block on behalf of a community
      add(:community_id, references("mn_community", on_delete: :nilify_all))
      # the thing being blocked
      add(:context_id, weak_pointer(), null: true)
      add(:published_at, :timestamptz)
      add(:muted_at, :timestamptz)
      add(:blocked_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_block, :updated_at))
    create(unique_index(:mn_block, :canonical_url))
    create(unique_index(:mn_block, [:creator_id, :context_id], where: "deleted_at is null"))
    create(index(:mn_block, :context_id))

    ### features

    create table(:mn_feature) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true, null: false)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
    end

    create(unique_index(:mn_feature, :canonical_url))
    create(unique_index(:mn_feature, [:creator_id, :context_id], where: "deleted_at is null"))
    create(index(:mn_feature, :context_id))

    ### tagging

    create table(:mn_tag_category) do
      add(:canonical_url, :text)
      add(:name, :text)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_tag_category, :updated_at))
    create(unique_index(:mn_tag_category, :canonical_url))
    create(unique_index(:mn_tag_category, :name, where: "deleted_at is null"))

    create table(:mn_tag, primary_key: false) do
      add(:id, weak_pointer(), null: true, primary_key: true)
      add(:canonical_url, :text)
      add(:name, :text, null: false)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_tag, :updated_at))
    create(unique_index(:mn_tag, :canonical_url))
    create(unique_index(:mn_tag, :name, where: "deleted_at is null"))

    create table(:mn_tagging, primary_key: false) do
      add(:id, weak_pointer(), null: true, primary_key: true)
      add(:canonical_url, :text)
      add(:tag_id, references("mn_tag", on_delete: :nilify_all))
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true)
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:is_local, :boolean, null: false)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(index(:mn_tagging, :updated_at))
    create(unique_index(:mn_tagging, :canonical_url))

    create(
      unique_index(:mn_tagging, [:tag_id, :creator_id, :context_id], where: "deleted_at is null")
    )

    create(index(:mn_tagging, :creator_id))
    create(index(:mn_tagging, :context_id))

    create table(:mn_activity) do
      add(:canonical_url, :text)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:context_id, weak_pointer(), null: true)
      add(:verb, :text, null: false)
      add(:is_local, :boolean, null: false)
      add(:deleted_at, :timestamptz)
      add(:published_at, :timestamptz)
      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:mn_activity, :canonical_url))
    create(index(:mn_activity, :creator_id))
    create(index(:mn_activity, :context_id))
    create(index(:mn_activity, :updated_at))
    create(index(:mn_activity, :published_at))

    create table(:mn_feed_activity) do
      add(:feed_id, references("mn_feed", on_delete: :delete_all), null: false)
      add(:activity_id, references("mn_activity", on_delete: :nilify_all))
    end

    create(index(:mn_feed_activity, :feed_id))
    create(index(:mn_feed_activity, :activity_id))

    create table(:access_token) do
      add(:user_id, references("mn_user", on_delete: :delete_all), null: false)
      add(:expires_at, :timestamptz, null: false)
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    # now we are going to do things with what we've already created.
    # ecto naturally wants to delay running any of this because we
    # might be running in mysql which doesn't have DDL transactions
    # as we happen to know we're not, carry on...
    flush()

    # now = DateTime.utc_now()

    tables =
      Enum.map(@meta_tables, fn name ->
        %{"id" => ULID.bingenerate(), "table" => name}
      end)

    # TODO - fully upgrade to new Pointers
    {_, _} = Repo.insert_all("pointers_table", tables)

    tables =
      Enum.reduce(tables, %{}, fn %{"id" => id, "table" => table}, acc ->
        Map.put(acc, table, id)
      end)

    # :ok = execute """
    # create function pointers_trigger()
    # returns trigger
    # as $$
    # declare
    #   table_id uuid;
    # begin
    #   select id into table_id
    #   from pointers_table
    #   where "table" = TG_TABLE_NAME;
    #   if table_id is null then
    #     raise exception 'Table % not found in pointers_table', TG_TABLE_NAME;
    #   end if;
    #   insert into mn_pointer (id, table_id)
    #   values (NEW.id, table_id);
    #   return NEW;
    # end;
    # $$ language plpgsql
    # """

    for table <- @meta_tables do
      :ok =
        execute("""
        create trigger "pointers_trigger_#{table}"
        before insert on "#{table}"
        for each row
        execute procedure pointers_trigger()
        """)
    end

    # langs =
    #   Enum.map(@languages, fn {code2, code3, name, name2} ->
    #     %{
    #       "id" => ULID.bingenerate(),
    #       "iso_code2" => code2,
    #       "iso_code3" => code3,
    #       "english_name" => name,
    #       "local_name" => name2,
    #       "updated_at" => now
    #     }
    #   end)

    # Repo.insert_all("mn_language", langs)

    # country_pointers = Enum.map(@countries, fn _ -> Ecto.ULID.bingenerate() end)

    # {_, _} =
    #   Repo.insert_all(
    #     Pointers.Pointer,
    #     Enum.map(country_pointers, fn id -> %{"id" => id, "table_id" => tables["mn_country"]} end)
    #   )

    # countries =
    #   Enum.map(@countries, fn {code2, code3, name, name2} ->
    #     %{
    #       "id" => ULID.bingenerate(),
    #       "iso_code2" => code2,
    #       "iso_code3" => code3,
    #       "english_name" => name,
    #       "local_name" => name2,
    #       "updated_at" => now
    #     }
    #   end)

    # Repo.insert_all("mn_country", countries)

    # cats =
    #   Enum.map(@tag_categories, fn {pointer, cat} ->
    #     %{"id" => pointer,
    #       "name" => cat,
    #       "updated_at" => now,
    #       "published_at" => now}
    #   end)
    # Repo.insert_all("mn_tag_category", cats)

    ### last activity views

    # user

    ### follower counts

    # user

    :ok =
      execute("""
      create view mn_user_follower_count as
      select mn_user.id as user_id,
             coalesce(count(mn_follow.creator_id), 0) as count
      from mn_user left join mn_follow on mn_user.id = mn_follow.context_id
      where mn_follow.deleted_at is null
      group by mn_user.id
      """)

    # community

    :ok =
      execute("""
      create view mn_community_follower_count as
      select mn_community.id as community_id,
             coalesce(count(mn_follow.creator_id), 0) as count
      from mn_community left join mn_follow on mn_community.id = mn_follow.context_id
      where mn_follow.deleted_at is null
      group by mn_community.id
      """)

    # collection

    :ok =
      execute("""
      create view mn_collection_follower_count as
      select mn_collection.id as collection_id,
             coalesce(count(mn_follow.creator_id), 0) as count
      from mn_collection left join mn_follow on mn_collection.id = mn_follow.context_id
      where mn_follow.deleted_at is null
      group by mn_collection.id
      """)

    # thread

    :ok =
      execute("""
      create view mn_thread_follower_count as
      select mn_thread.id as thread_id,
             coalesce(count(mn_follow.creator_id), 0) as count
      from mn_thread left join mn_follow on mn_thread.id = mn_follow.context_id
      where mn_follow.deleted_at is null
      group by mn_thread.id
      """)

    ### following counts

    # user

    :ok =
      execute("""
      create view mn_user_following_count as
      select mn_user.id as user_id,
             coalesce(count(mn_follow.context_id), 0) as count
      from mn_user left join mn_follow on mn_user.id = mn_follow.creator_id
      where mn_follow.deleted_at is null
      group by mn_user.id
      """)
  end

  def down do
    for table <- @meta_tables do
      :ok = execute("drop trigger pointers_trigger_#{table} on #{table}")
    end

    :ok = execute("drop function pointers_trigger()")

    :ok = execute("drop view if exists mn_user_following_count")
    :ok = execute("drop view if exists mn_thread_follower_count")
    :ok = execute("drop view if exists mn_collection_follower_count")
    :ok = execute("drop view if exists mn_community_follower_count")
    :ok = execute("drop view if exists mn_user_follower_count")

    flush()

    drop(table(:access_token))

    drop(index(:mn_feed_activity, :feed_id))
    drop(index(:mn_feed_activity, :activity_id))
    drop(table(:mn_feed_activity))

    drop(index(:mn_activity, :canonical_url))
    drop(index(:mn_activity, :creator_id))
    drop(index(:mn_activity, :context_id))
    drop(index(:mn_activity, :updated_at))
    drop(index(:mn_activity, :published_at))
    drop(table(:mn_activity))

    drop(index(:mn_tagging, :updated_at))
    drop(index(:mn_tagging, :canonical_url))
    drop(index(:mn_tagging, [:tag_id, :creator_id, :context_id]))
    drop(index(:mn_tagging, :creator_id))
    drop(index(:mn_tagging, :context_id))
    drop(table(:mn_tagging))

    drop(index(:mn_tag, :updated_at))
    drop(index(:mn_tag, :canonical_url))
    drop(index(:mn_tag, :name))
    drop(table(:mn_tag))

    drop(index(:mn_tag_category, :updated_at))
    drop(index(:mn_tag_category, :canonical_url))
    drop(index(:mn_tag_category, :name))
    drop(table(:mn_tag_category))

    drop(index(:mn_feature, :canonical_url))
    drop(index(:mn_feature, [:creator_id, :context_id]))
    drop(index(:mn_feature, :context_id))
    drop(table(:mn_feature))

    drop(index(:mn_block, :updated_at))
    drop(index(:mn_block, :canonical_url))
    drop(index(:mn_block, [:creator_id, :context_id]))
    drop(index(:mn_block, :context_id))
    drop(table(:mn_block))

    drop(index(:mn_follow, :updated_at))
    drop(index(:mn_follow, :canonical_url))
    drop(index(:mn_follow, [:creator_id, :context_id]))
    drop(index(:mn_follow, :context_id))
    drop(table(:mn_follow))

    drop(index(:mn_like, :updated_at))
    drop(index(:mn_like, :canonical_url))
    drop(index(:mn_like, [:creator_id, :context_id]))
    drop(index(:mn_like, :context_id))
    drop(table(:mn_like))

    drop(index(:mn_flag, :updated_at))
    drop(index(:mn_flag, :canonical_url))
    drop(index(:mn_flag, [:creator_id, :context_id]))
    drop(index(:mn_flag, :context_id))
    drop(index(:mn_flag, :community_id))
    drop(table(:mn_flag))

    drop(index(:mn_comment, :updated_at))
    drop(index(:mn_comment, :canonical_url))
    drop(index(:mn_comment, :creator_id))
    drop(index(:mn_comment, :thread_id))
    drop(table(:mn_comment))

    drop(index(:mn_thread, :updated_at))
    drop(index(:mn_thread, :canonical_url))
    drop(index(:mn_thread, :creator_id))
    drop(index(:mn_thread, :context_id))
    drop(table(:mn_thread))

    drop(index(:mn_resource, :updated_at))
    drop(index(:mn_resource, :canonical_url))
    drop(index(:mn_resource, :creator_id))
    # drop(index(:mn_resource, :collection_id))
    drop(index(:mn_resource, :primary_language_id))
    drop(table(:mn_resource))

    drop(index(:mn_collection, :updated_at))
    drop(index(:mn_collection, :actor_id))
    drop(index(:mn_collection, :creator_id))
    drop(index(:mn_collection, :community_id))
    drop(index(:mn_collection, :primary_language_id))
    drop(table(:mn_collection))

    drop(index(:mn_community, :updated_at))
    drop(index(:mn_community, :creator_id))
    drop(index(:mn_community, :actor_id))
    drop(index(:mn_community, :primary_language_id))
    drop(table(:mn_community))

    drop(index(:mn_user, :actor_id))
    drop(index(:mn_user, :local_user_id))
    drop(index(:mn_user, :primary_language_id))
    drop(table(:mn_user))

    drop(index(:mn_local_user_email_confirm_token, :local_user_id))
    drop(table(:mn_local_user_email_confirm_token))

    drop(index(:mn_local_user_reset_password_token, :local_user_id))
    drop(table(:mn_local_user_reset_password_token))

    drop(index(:mn_local_user, :email))
    drop(table(:mn_local_user))

    drop(
      index(:mn_actor, [:preferred_username, :peer_id],
        name: :mn_actor_preferred_username_peer_id_index
      )
    )

    drop(index(:mn_actor, [:preferred_username], name: :mn_actor_peer_id_null_index))
    drop(table(:mn_actor))

    drop(index(:mn_peer, :domain))
    drop(index(:mn_peer, :ap_url_base))
    drop(table(:mn_peer))

    drop(index(:mn_access_register_email, :email))
    drop(table(:mn_access_register_email))

    drop(index(:mn_access_register_email_domain, :domain))
    drop(table(:mn_access_register_email_domain))

    drop(index(:mn_language, :iso_code2))
    drop(index(:mn_language, :iso_code3))
    drop(table(:mn_language))

    drop(index(:mn_country, :iso_code2))
    drop(index(:mn_country, :iso_code3))
    drop(table(:mn_country))

    drop(
      index(:mn_feed_subscription, [:subscriber_id, :feed_id],
        name: :mn_feed_subscription_subscriber_feed_idx
      )
    )

    drop(index(:mn_feed_subscription, :feed_id))
    drop(index(:mn_feed_subscription, :subscriber_id))
    drop(table(:mn_feed_subscription))

    drop(table(:mn_feed))

    # drop(index(:mn_pointer, :table_id))
    # drop(table(:mn_pointer))

    # drop(index(:pointers_table, :table))
    # drop(table(:pointers_table))
  end
end
