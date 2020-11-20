defmodule CommonsPub.Utils.Simulation do
  # Basic data

  alias CommonsPub.{
    Access,
    Activities,
    Communities,
    Collections,
    Flags,
    Follows,
    Features,
    Likes,
    Peers,
    # Uploads,
    Users,
    Resources,
    Threads,
    Threads.Comments,
    Users.User
  }

  import CommonsPub.Utils.Trendy

  def maybe_assert(value) do
    require ExUnit.Assertions
    ExUnit.Assertions.assert(value)
  end

  @integer_min -32768
  @integer_max 32767

  @file_fixtures [
    "test/fixtures/images/150.png",
    "test/fixtures/very-important.pdf"
  ]

  @url_fixtures [
    "https://duckduckgo.com",
    "http://commonspub.org",
    "https://en.wikipedia.org/wiki/Ursula_K._Le_Guin",
    "https://upload.wikimedia.org/wikipedia/en/f/fc/TheDispossed%281stEdHardcover%29.jpg"
  ]

  @doc "Returns true"
  def truth(), do: true
  @doc "Returns false"
  def falsehood(), do: false
  @doc "Generates a random boolean"
  def bool(), do: Faker.Util.pick([true, false])
  @doc "Generate a random boolean that can also be nil"
  def maybe_bool(), do: Faker.Util.pick([true, false, nil])
  @doc "Generate a random signed integer"
  def integer(), do: Faker.random_between(@integer_min, @integer_max)
  @doc "Generate a random positive integer"
  def pos_integer(), do: Faker.random_between(0, @integer_max)
  @doc "Generate a random negative integer"
  def neg_integer(), do: Faker.random_between(@integer_min, 0)
  @doc "Generate a random floating point number"
  def float(), do: Faker.random_uniform()
  @doc "Generates a random url"
  def url(), do: Faker.Internet.url() <> "/"
  @doc "Picks a path from a set of available files."
  def path(), do: Faker.Util.pick(@file_fixtures)
  @doc "Picks a remote url from a set of available ones."
  def content_url(), do: Faker.Util.pick(@url_fixtures)
  @doc "Generate a random content type"
  def content_type(), do: Faker.File.mime_type()
  @doc "Picks a name"
  def name(), do: Faker.Company.name()
  @doc "Generates a random password string"
  def password(), do: base64()
  @doc "Generates a random date of birth based on an age range of 18-99"
  def date_of_birth(), do: Faker.Date.date_of_birth(18..99)
  @doc "Picks a date up to 300 days in the past, not including today"
  def past_date(), do: Faker.Date.backward(300)
  @doc "Picks a datetime up to 300 days in the past, not including today"
  def past_datetime(), do: Faker.DateTime.backward(300)
  @doc "Same as past_datetime, but as an ISO8601 formatted string."
  def past_datetime_iso(), do: DateTime.to_iso8601(past_datetime())
  @doc "Picks a date up to 300 days in the future, not including today"
  def future_date(), do: Faker.Date.forward(300)
  @doc "Picks a datetime up to 300 days in the future, not including today"
  def future_datetime(), do: Faker.DateTime.forward(300)
  @doc "Same as future_datetime, but as an ISO8601 formatted string."
  def future_datetime_iso(), do: DateTime.to_iso8601(future_datetime())
  @doc "Generates a random paragraph"
  def paragraph(), do: Faker.Lorem.paragraph()
  @doc "Generates random base64 text"
  def base64(), do: Faker.String.base64()

  # def primary_language(), do: "en"

  # Custom data

  @doc "Picks a summary text paragraph"
  def summary(), do: paragraph()
  @doc "Picks an icon url"
  def icon(), do: Faker.Avatar.image_url()
  @doc "Picks an image url"
  def image(), do: Faker.Avatar.image_url()
  @doc "Picks a fake signing key"
  def signing_key(), do: nil
  @doc "A random license for content"
  def license(), do: Faker.Util.pick(["GPLv3", "BSDv3", "AGPL", "Creative Commons"])
  @doc "Returns a city and country"
  def location(), do: Faker.Address.city() <> ", " <> Faker.Address.country()
  @doc "A website address"
  def website(), do: Faker.Internet.url()
  @doc "A verb to be used for an activity."
  def verb(), do: Faker.Util.pick(["created", "updated", "deleted"])

  # Unique data

  @doc "Generates a random unique uuid"
  def uuid(), do: Zest.Faking.unused(&Faker.UUID.v4/0, :uuid)
  @doc "Generates a random unique ulid"
  def ulid(), do: Ecto.ULID.generate()
  @doc "Generates a random unique email"
  def email(), do: Zest.Faking.unused(&Faker.Internet.email/0, :email)
  @doc "Generates a random domain name"
  def domain(), do: Zest.Faking.unused(&Faker.Internet.domain_name/0, :domain)
  @doc "Generates the first half of an email address"
  def email_user(), do: Zest.Faking.unused(&Faker.Internet.user_name/0, :email_user)
  @doc "Picks a unique random url for an ap endpoint"
  def ap_url_base(), do: Zest.Faking.unused(&url/0, :ap_url_base)

  @doc "Generates a random username"
  def username(), do: CommonsPub.Characters.sanitise_username(Faker.Internet.user_name())

  @doc "Picks a unique preferred_username"
  def preferred_username(), do: Zest.Faking.unused(&username/0, :preferred_username)

  @doc "Picks a random canonical url and makes it unique"
  def canonical_url(), do: Faker.Internet.url() <> "/" <> ulid()

  # utils

  def short_count(), do: Faker.random_between(0, 3)
  def med_count(), do: Faker.random_between(3, 9)
  def long_count(), do: Faker.random_between(10, 25)
  def short_list(gen), do: Faker.Util.list(short_count(), gen)
  def med_list(gen), do: Faker.Util.list(med_count(), gen)
  def long_list(gen), do: Faker.Util.list(long_count(), gen)
  def one_of(gens), do: Faker.Util.pick(gens).()

  def maybe_one_of(list), do: Faker.Util.pick(list ++ [nil])

  def page_info(base \\ %{}) do
    base
    |> Map.put_new_lazy(:start_cursor, &uuid/0)
    |> Map.put_new_lazy(:end_cursor, &uuid/0)
    |> Map.put(:__struct__, CommonsPub.GraphQL.PageInfo)
  end

  def long_node_list(base \\ %{}, gen) do
    base
    |> Map.put_new_lazy(:page_info, &page_info/0)
    |> Map.put_new_lazy(:total_count, &pos_integer/0)
    |> Map.put_new_lazy(:nodes, fn -> long_list(gen) end)
    |> Map.put(:__struct__, CommonsPub.GraphQL.NodeList)
  end

  def long_edge_list(base \\ %{}, gen) do
    base
    |> Map.put_new_lazy(:page_info, &page_info/0)
    |> Map.put_new_lazy(:total_count, &pos_integer/0)
    |> Map.put_new_lazy(:edges, fn -> long_list(fn -> edge(gen) end) end)
    |> Map.put(:__struct__, CommonsPub.GraphQL.EdgeList)
  end

  def edge(base \\ %{}, gen) do
    base
    |> Map.put_new_lazy(:cursor, &uuid/0)
    |> Map.put_new_lazy(:node, gen)
    |> Map.put(:__struct__, CommonsPub.GraphQL.Edge)
  end

  # Widely useful schemas:

  def character(base \\ %{}) do
    uname = preferred_username()

    base
    |> Map.put_new_lazy(:preferred_username, fn -> uname end)
    |> Map.put_new_lazy(:canonical_url, fn ->
      CommonsPub.ActivityPub.Utils.generate_actor_url(uname)
    end)
    |> Map.put_new_lazy(:signing_key, &signing_key/0)
  end

  def content_mirror_input(base \\ %{}) do
    base
    |> Map.put_new_lazy(:url, &content_url/0)
  end

  def content_upload_input(base \\ %{}) do
    base
    |> Map.put_new_lazy(:upload, fn ->
      path = path()

      %Plug.Upload{
        path: path,
        filename: Path.basename(path),
        content_type: content_type()
      }
    end)
  end

  def content_input(base \\ %{}) do
    # gen = Faker.Util.pick([&content_mirror_input/1, &content_upload_input/1])
    # FIXME: need to make fake uploads work
    gen = &content_mirror_input/1
    gen.(base)
  end

  def language(base \\ %{}) do
    base
    # todo: these can't both be right
    |> Map.put_new_lazy(:id, &ulid/0)
    |> Map.put_new_lazy(:iso_code2, &Faker.Address.country_code/0)
    |> Map.put_new_lazy(:iso_code3, &Faker.Address.country_code/0)
    |> Map.put_new_lazy(:english_name, &Faker.Address.country/0)
    |> Map.put_new_lazy(:local_name, &Faker.Address.country/0)
  end

  def country(base \\ %{}) do
    base
    # todo: these can't both be right
    |> Map.put_new_lazy(:id, &ulid/0)
    |> Map.put_new_lazy(:iso_code2, &Faker.Address.country_code/0)
    |> Map.put_new_lazy(:iso_code3, &Faker.Address.country_code/0)
    |> Map.put_new_lazy(:english_name, &Faker.Address.country/0)
    |> Map.put_new_lazy(:local_name, &Faker.Address.country/0)
  end

  def peer(base \\ %{}) do
    base
    |> Map.put_new_lazy(:ap_url_base, &ap_url_base/0)
    |> Map.put_new_lazy(:domain, &domain/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def activity(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:verb, &verb/0)
    |> Map.put_new_lazy(:is_local, &bool/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
  end

  def local_user(base \\ %{}) do
    base
    |> Map.put_new_lazy(:email, &email/0)
    |> Map.put_new_lazy(:password, &password/0)
    |> Map.put_new_lazy(:wants_email_digest, &bool/0)
    |> Map.put_new_lazy(:wants_notifications, &bool/0)
    |> Map.put_new_lazy(:is_instance_admin, &falsehood/0)
    |> Map.put_new_lazy(:is_confirmed, &falsehood/0)
  end

  def user(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:summary, &summary/0)
    |> Map.put_new_lazy(:website, &website/0)
    |> Map.put_new_lazy(:location, &location/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
    |> Map.merge(character(base))
    |> Map.merge(local_user(base))
  end

  def registration_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("email", &email/0)
    |> Map.put_new_lazy("password", &password/0)
    |> Map.put_new_lazy("preferredUsername", &preferred_username/0)
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("summary", &summary/0)
    |> Map.put_new_lazy("location", &location/0)
    |> Map.put_new_lazy("website", &website/0)
    # |> Map.put_new_lazy("primaryLanguageId", &ulid/0)
    |> Map.put_new_lazy("wantsEmailDigest", &bool/0)
    |> Map.put_new_lazy("wantsNotifications", &bool/0)
  end

  def profile_update_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("summary", &summary/0)
    |> Map.put_new_lazy("location", &location/0)
    |> Map.put_new_lazy("website", &website/0)
    |> Map.put_new_lazy("email", &email/0)
    # |> Map.put_new_lazy("primaryLanguageId", &ulid/0)
    |> Map.put_new_lazy("wantsEmailDigest", &bool/0)
    |> Map.put_new_lazy("wantsNotifications", &bool/0)
  end

  def community(base \\ %{}) do
    base
    # |> Map.put_new_lazy(:primary_language_id, &ulid/0)
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:summary, &summary/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
    |> Map.put_new_lazy(:is_featured, &bool/0)
    |> Map.merge(character(base))
  end

  def community_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("preferredUsername", &preferred_username/0)
    # |> Map.put_new_lazy("primaryLanguageId", &ulid/0)
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("summary", &summary/0)
  end

  def community_update_input(base \\ %{}) do
    base
    # |> Map.put_new_lazy("primaryLanguageId", &ulid/0)
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("summary", &summary/0)
  end

  def collection(base \\ %{}) do
    base
    # |> Map.put_new_lazy(:primary_language_id, &ulid/0)
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:summary, &summary/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
    |> Map.put_new_lazy(:is_featured, &bool/0)
    |> Map.merge(character(base))
  end

  def collection_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("preferredUsername", &preferred_username/0)
    |> collection_update_input()
  end

  def collection_update_input(base \\ %{}) do
    base
    # |> Map.put_new_lazy("primaryLanguageId", &ulid/0)
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("summary", &summary/0)
  end

  def resource(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:summary, &summary/0)
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:license, &license/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_hidden, &falsehood/0)
  end

  def resource_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("summary", &summary/0)
    |> Map.put_new_lazy("license", &license/0)
    |> Map.put("subject", "2290")
    |> Map.put("level", "1100")
    |> Map.put("language", "English")

    # |> Map.put_new_lazy("freeAccess", &maybe_bool/0)
    # |> Map.put_new_lazy("publicAccess", &maybe_bool/0)
    # |> Map.put_new_lazy("learningResourceType", &learning_resource/0)
    # |> Map.put_new_lazy("educationalUse", &educational_use/0)
    # |> Map.put_new_lazy("timeRequired", &pos_integer/0)
    # |> Map.put_new_lazy("typicalAgeRange", &age_range/0)
    # |> Map.put_new_lazy("primaryLanguageId", &primary_language/0)
  end

  def thread(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_locked, &falsehood/0)
    |> Map.put_new_lazy(:is_hidden, &falsehood/0)
  end

  def comment(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:content, &paragraph/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_local, &bool/0)
    |> Map.put_new_lazy(:is_hidden, &falsehood/0)
    |> Map.put_new_lazy(:content, &paragraph/0)
  end

  def comment_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("content", &paragraph/0)
  end

  def like(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
  end

  def like_input(base \\ %{}) do
    base
    |> Map.put_new_lazy(:is_local, &truth/0)
  end

  def feature_input(base \\ %{}) do
    base
    |> Map.put_new_lazy(:is_local, &truth/0)
  end

  def flag(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:message, &paragraph/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
    |> Map.put_new_lazy(:is_resolved, &falsehood/0)
  end

  def flag_input(base \\ %{}) do
    base
    |> Map.put_new_lazy(:message, &paragraph/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
  end

  def follow(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_muted, &falsehood/0)
  end

  def follow_input(base \\ %{}) do
    base
    |> Map.put_new_lazy(:is_local, &truth/0)
  end

  def block(base \\ %{}) do
    base
    |> Map.put_new_lazy(:canonical_url, &canonical_url/0)
    |> Map.put_new_lazy(:is_local, &truth/0)
    |> Map.put_new_lazy(:is_blocked, &truth/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_muted, &falsehood/0)
  end

  # def tag(base \\ %{}) do
  #   base
  #   |> Map.put_new_lazy(:is_public, &truth/0)
  #   |> Map.put_new_lazy(:name, &name/0)
  # end

  # def community_role(base \\ %{}) do
  #   base
  # end

  def fake_user(overrides \\ %{}, opts \\ []) when is_map(overrides) and is_list(opts) do
    CommonsPub.Users.register(user(overrides), public_registration: true)
  end

  def fake_user!(overrides \\ %{}, opts \\ []) when is_map(overrides) and is_list(opts) do
    with {:ok, user} <- fake_user(overrides, opts) do
      maybe_confirm_user_email(user, opts)
    end
  end

  defp maybe_confirm_user_email(user, opts) do
    # IO.inspect(opts)

    if Keyword.get(opts, :confirm_email) do
      {:ok, user} = CommonsPub.Users.confirm_email(user)
      user
    else
      user
    end
  end

  def fake_admin!(overrides \\ %{}, opts \\ []) do
    fake_user!(Map.put(overrides, :is_instance_admin, true), opts)
  end

  def fake_register_email_domain_access!(domain \\ domain())
      when is_binary(domain) do
    {:ok, wl} = Access.create_register_email_domain(domain)
    wl
  end

  def fake_register_email_access!(email \\ email())
      when is_binary(email) do
    {:ok, wl} = Access.create_register_email(email)
    wl
  end

  # def fake_language!(overrides \\ %{}) do
  #   overrides
  #   |> Map.get(:id, "en")
  #   |> Localisation.language!()
  # end

  def fake_peer!(overrides \\ %{}) when is_map(overrides) do
    {:ok, peer} = Peers.create(peer(overrides))
    peer
  end

  def fake_activity!(user, context, overrides \\ %{}) do
    {:ok, activity} = Activities.create(user, context, activity(overrides))
    maybe_assert(activity.creator_id == user.id)
    activity
  end

  def fake_character!(overrides \\ %{}) when is_map(overrides) do
    with {:ok, user} <- fake_user(overrides) do
      user.character
    end
  end

  def fake_token!(%User{} = user) do
    {:ok, token} = Access.unsafe_put_token(user)
    maybe_assert(token.user_id == user.id)
    token
  end

  def fake_content!(%User{} = user, overrides \\ %{}) do
    {:ok, content} =
      CommonsPub.Uploads.upload(
        CommonsPub.Uploads.ResourceUploader,
        user,
        content_input(overrides),
        %{}
      )

    maybe_assert(content.uploader_id == user.id)
    content
  end

  def fake_community!(user, context \\ nil, overrides \\ %{})

  def fake_community!(%User{} = user, context, %{} = overrides) do
    {:ok, community} = Communities.create(user, context, community(overrides))
    maybe_assert(community.creator_id == user.id)
    community
  end

  def fake_collection!(user, context \\ nil, overrides \\ %{})

  def fake_collection!(user, context, overrides)
      when is_map(overrides) and is_nil(context) do
    {:ok, collection} = Collections.create(user, collection(overrides))
    maybe_assert(collection.creator_id == user.id)
    collection
  end

  def fake_collection!(user, context, overrides) when is_map(overrides) do
    {:ok, collection} = Collections.create(user, context, collection(overrides))
    maybe_assert(collection.creator_id == user.id)
    collection
  end

  def fake_resource!(user, context \\ nil, overrides \\ %{}) when is_map(overrides) do
    attrs =
      overrides
      |> resource()
      |> Map.put(:content_id, fake_content!(user, overrides).id)

    {:ok, resource} = Resources.create(user, context, attrs)
    maybe_assert(resource.creator_id == user.id)
    # maybe_assert resource.context_id == context.id
    resource
  end

  def fake_thread!(user, context, overrides \\ %{})

  def fake_thread!(user, nil, overrides) when is_map(overrides) do
    {:ok, thread} = Threads.create(user, thread(overrides))
    maybe_assert(thread.creator_id == user.id)
    thread
  end

  def fake_thread!(user, context, overrides) when is_map(overrides) do
    {:ok, thread} = Threads.create(user, thread(overrides), context)
    maybe_assert(thread.creator_id == user.id)
    thread
  end

  def fake_comment!(user, thread, overrides \\ %{}) when is_map(overrides) do
    {:ok, comment} = Comments.create(user, thread, comment(overrides))
    maybe_assert(comment.creator_id == user.id)
    comment
  end

  def fake_reply!(user, thread, comment, overrides \\ %{}) when is_map(overrides) do
    fake = comment(Map.put_new(overrides, :in_reply_to, comment.id))
    {:ok, comment} = Comments.create(user, thread, fake)
    maybe_assert(comment.creator_id == user.id)
    comment
  end

  def some_fake_users!(opts \\ %{}, some_arg) do
    some(some_arg, fn -> fake_user!(opts) end)
  end

  def some_fake_communities!(opts \\ %{}, some_arg, users) do
    flat_pam(users, &some(some_arg, fn -> fake_community!(&1, opts) end))
  end

  def some_fake_resources!(opts \\ %{}, some_arg, users, collections) do
    flat_pam_product_some(users, collections, some_arg, &fake_resource!(&1, &2, opts))
  end

  def some_fake_collections!(opts \\ %{}, some_arg, users, communities) do
    flat_pam_product_some(users, communities, some_arg, &fake_collection!(&1, &2, opts))
  end

  def some_randomer_flags!(opts \\ %{}, some_arg, context) do
    users = some_fake_users!(opts, some_arg)
    pam(users, &flag!(&1, context, opts))
  end

  def some_randomer_follows!(opts \\ %{}, some_arg, context) do
    users = some_fake_users!(opts, some_arg)
    pam(users, &follow!(&1, context, opts))
  end

  def some_randomer_likes!(opts \\ %{}, some_arg, context) do
    users = some(some_arg, &fake_user!/0)
    pam(users, &like!(&1, context, opts))
  end

  def like!(user, context, args \\ %{}) do
    {:ok, like} = Likes.create(user, context, like_input(args))
    maybe_assert(like.creator_id == user.id)
    maybe_assert(like.context_id == context.id)
    like
  end

  def flag!(user, context, args \\ %{}) do
    {:ok, flag} = Flags.create(user, context, flag_input(args))
    maybe_assert(flag.creator_id == user.id)
    maybe_assert(flag.context_id == context.id)
    flag
  end

  def follow!(user, context, args \\ %{}) do
    {:ok, follow} = Follows.create(user, context, follow_input(args))
    maybe_assert(follow.creator_id == user.id)
    maybe_assert(follow.context_id == context.id)
    follow
  end

  def feature!(user, context, args \\ %{}) do
    {:ok, feature} = Features.create(user, context, feature_input(args))
    maybe_assert(feature.creator_id == user.id)
    maybe_assert(feature.context_id == context.id)
    feature
  end
end
