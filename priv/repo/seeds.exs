# Generate some fake data and put it in the DB for testing/development purposes

import CommonsPub.Utils.Simulation

System.put_env("SEARCH_INDEXING_DISABLED", "true")

admin =
  %{
    email: "root@localhost.dev",
    preferred_username: System.get_env("SEEDS_USER", "root"),
    password: System.get_env("SEEDS_PW", "123456"),
    name: System.get_env("SEEDS_USER", "root"),
    is_instance_admin: true
  }
  |> fake_user!(confirm_email: true)

# create some users
users = for _ <- 1..2, do: fake_user!()
random_user = fn -> Faker.Util.pick(users) end

# start some communities
communities = for _ <- 1..2, do: fake_community!(random_user.())
subcommunities = for _ <- 1..2, do: fake_community!(random_user.(), Faker.Util.pick(communities))
maybe_random_community = fn -> maybe_one_of(communities ++ subcommunities) end

# create fake collections
collections = for _ <- 1..4, do: fake_collection!(random_user.(), maybe_random_community.())
subcollections = for _ <- 1..2, do: fake_collection!(random_user.(), Faker.Util.pick(collections))
maybe_random_collection = fn -> maybe_one_of(collections ++ subcollections) end

# start fake threads
for _ <- 1..3 do
  user = random_user.()
  thread = fake_thread!(user, maybe_random_community.())
  comment = fake_comment!(user, thread)
  # reply to it
  reply = fake_comment!(random_user.(), thread, %{in_reply_to_id: comment.id})
  subreply = fake_comment!(random_user.(), thread, %{in_reply_to_id: reply.id})
  subreply2 = fake_comment!(random_user.(), thread, %{in_reply_to_id: subreply.id})
end

# more fake threads
for _ <- 1..2 do
  user = random_user.()
  thread = fake_thread!(user, maybe_random_collection.())
  comment = fake_comment!(user, thread)
end

# post some links/resources
for _ <- 1..2, do: fake_resource!(random_user.(), maybe_random_community.())
for _ <- 1..2, do: fake_resource!(random_user.(), maybe_random_collection.())

# define some tags/categories
if(CommonsPub.Config.module_enabled?(CommonsPub.Tag.Simulate)) do
  for _ <- 1..2 do
    category = CommonsPub.Tag.Simulate.fake_category!(random_user.())
    _subcategory = CommonsPub.Tag.Simulate.fake_category!(random_user.(), category)
  end
end

# define some geolocations
if(CommonsPub.Config.module_enabled?(Geolocation.Simulate)) do
  for _ <- 1..2,
      do: Geolocation.Simulate.fake_geolocation!(random_user.(), maybe_random_community.())

  for _ <- 1..2,
      do: Geolocation.Simulate.fake_geolocation!(random_user.(), maybe_random_collection.())
end

# define some units
if(CommonsPub.Config.module_enabled?(Measurement.Simulate)) do
  for _ <- 1..2 do
    unit1 = Measurement.Simulate.fake_unit!(random_user.(), maybe_random_community.())
    unit2 = Measurement.Simulate.fake_unit!(random_user.(), maybe_random_collection.())
  end
end

# conduct some fake economic activities
if(CommonsPub.Config.module_enabled?(ValueFlows.Simulate)) do
  for _ <- 1..2 do
    user = random_user.()

    # some lonesome intents and proposals
    intent = ValueFlows.Simulate.fake_intent!(user)
    proposal = ValueFlows.Simulate.fake_proposal!(user)
  end

  for _ <- 1..2 do
    user = random_user.()

    _process_spec = ValueFlows.Simulate.fake_process_specification!(user)
    res_spec = ValueFlows.Simulate.fake_resource_specification!(user)

    # some proposed intents
    intent = ValueFlows.Simulate.fake_intent!(user, %{resource_conforms_to: res_spec})
    proposal = ValueFlows.Simulate.fake_proposal!(user)
    ValueFlows.Simulate.fake_proposed_to!(random_user.(), proposal)
    ValueFlows.Simulate.fake_proposed_intent!(proposal, intent)

    # define some geolocations
    if(CommonsPub.Config.module_enabled?(Geolocation.Simulate)) do

      places = for _ <- 1..2, do: Geolocation.Simulate.fake_geolocation!(random_user.())
random_place = fn -> Faker.Util.pick(places) end


      for _ <- 1..2 do

        # define some intents with geolocation
        intent =
          ValueFlows.Simulate.fake_intent!(
            random_user.(),
            %{at_location: random_place.()}
          )

        # define some proposals with geolocation
        proposal = ValueFlows.Simulate.fake_proposal!(user, %{eligible_location: random_place.()})

        # both with geo
        intent =
          ValueFlows.Simulate.fake_intent!(
            random_user.(),
            %{at_location: random_place.()}
          )

        proposal = ValueFlows.Simulate.fake_proposal!(user, %{eligible_location: random_place.()})
        ValueFlows.Simulate.fake_proposed_intent!(proposal, intent)

        # some economic events
        user = random_user.()

        resource_inventoried_as = ValueFlows.Simulate.fake_economic_resource!(user, %{current_location: random_place.()})
        to_resource_inventoried_as = ValueFlows.Simulate.fake_economic_resource!(random_user.(), %{current_location: random_place.()})

        ValueFlows.Simulate.fake_economic_event!(
          user,
          %{
            to_resource_inventoried_as: to_resource_inventoried_as.id,
            resource_inventoried_as: resource_inventoried_as.id,
            action: Faker.Util.pick(["transfer", "move"]),
            at_location: random_place.()
          }
        )
      end
    end

    if(CommonsPub.Config.module_enabled?(Measurement.Simulate)) do
      unit1 = Measurement.Simulate.fake_unit!(random_user.(), maybe_random_community.())
      unit2 = Measurement.Simulate.fake_unit!(random_user.(), maybe_random_collection.())

      for _ <- 1..2 do
        # define some intents with measurements
        intent =
          ValueFlows.Simulate.fake_intent!(
            random_user.(),
            %{},
            Faker.Util.pick([unit1, unit2])
          )

        proposal = ValueFlows.Simulate.fake_proposal!(user)
        ValueFlows.Simulate.fake_proposed_intent!(proposal, intent)

        # some economic events
        user = random_user.()
        unit = Faker.Util.pick([unit1, unit2])

        resource_inventoried_as = ValueFlows.Simulate.fake_economic_resource!(user, %{}, unit)
        to_resource_inventoried_as = ValueFlows.Simulate.fake_economic_resource!(random_user.(), %{}, unit)

        ValueFlows.Simulate.fake_economic_event!(
          user,
          %{
            to_resource_inventoried_as: to_resource_inventoried_as.id,
            resource_inventoried_as: resource_inventoried_as.id,
            action: Faker.Util.pick(["transfer", "move"])
          },
          unit
        )
      end
    end
  end
end
