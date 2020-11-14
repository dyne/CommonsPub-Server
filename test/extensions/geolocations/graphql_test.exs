# SPDX-License-Identifier: AGPL-3.0-only
defmodule Geolocation.GraphQLTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Test.Faking
  import CommonsPub.Utils.Trendy, only: [some: 2]

  import Geolocation.Test.Faking
  import Geolocation.Simulate
  alias Geolocation.Geolocations

  describe "geolocation" do
    test "fetches a geolocation by ID" do
      user = fake_user!()
      geo = fake_geolocation!(user)

      q = geolocation_query()
      conn = user_conn(user)
      assert_geolocation(grumble_post_key(q, conn, :spatial_thing, %{id: geo.id}))
    end
  end

  describe "spatialThingPages" do
    test "fetches a paginated list of geolocations" do
      user = fake_user!()
      geos = some(5, fn -> fake_geolocation!(user) end)

      q = geolocation_pages_query()
      conn = user_conn(user)
      vars = %{
       limit: 2
      }
      assert geolocations = grumble_post_key(q, conn, :spatial_things_pages, vars)
      assert geolocations["totalCount"] == 5
      assert Enum.count(geolocations["edges"]) == 2
    end
  end

  describe "geolocation.in_scope_of" do
    test "returns the context of the geolocation" do
      user = fake_user!()
      comm = fake_community!(user)
      geo = fake_geolocation!(user, comm)

      q = geolocation_query(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      assert resp = grumble_post_key(q, conn, :spatial_thing, %{id: geo.id})
      assert resp["inScopeOf"]["__typename"] == "Community"
    end

    test "returns nil if there is no context" do
      user = fake_user!()
      geo = fake_geolocation!(user)

      q = geolocation_query(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      assert resp = grumble_post_key(q, conn, :spatial_thing, %{id: geo.id})
      assert is_nil(resp["inScopeOf"])
    end
  end

  describe "create_geolocation" do
    test "creates a new geolocation" do
      user = fake_user!()

      q = create_geolocation_mutation()
      conn = user_conn(user)
      vars = %{spatial_thing: geolocation_input()}
      assert_geolocation(grumble_post_key(q, conn, :create_spatial_thing, vars)["spatialThing"])
    end

    test "creates a new geolocation with a context" do
      user = fake_user!()
      comm = fake_community!(user)

      q = create_geolocation_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      vars = %{spatial_thing: geolocation_input(), in_scope_of: comm.id}
      assert_geolocation(grumble_post_key(q, conn, :create_spatial_thing, vars)["spatialThing"])
    end

    test "creates a new geolocation with a mappable address" do
      user = fake_user!()

      q = create_geolocation_mutation()
      conn = user_conn(user)
      vars = %{spatial_thing: geolocation_input(%{"lat" => nil, "long" => nil})}
      vars = put_in(vars, [:spatial_thing, "mappableAddress"], mappable_address())
      assert geo = grumble_post_key(q, conn, :create_spatial_thing, vars)["spatialThing"]
      assert_geolocation(geo)
      assert geo["lat"]
      assert geo["long"]
    end
  end

  describe "update_geolocation" do
    test "updates an existing geolocation" do
      user = fake_user!()
      geo = fake_geolocation!(user)

      q = update_geolocation_mutation()
      conn = user_conn(user)
      vars = %{spatial_thing: Map.put(geolocation_input(), "id", geo.id)}
      assert_geolocation(grumble_post_key(q, conn, :update_spatial_thing, vars)["spatialThing"])
    end

    test "updates an existing geolocation with only a name" do
      user = fake_user!()
      geo = fake_geolocation!(user)

      q = update_geolocation_mutation()
      conn = user_conn(user)
      vars = %{spatial_thing: %{
        "id" => geo.id,
        "name" => geolocation_input()["name"],
      }}
      assert updated = grumble_post_key(q,conn, :update_spatial_thing, vars)["spatialThing"]
      assert_geolocation(updated)
      assert updated["name"] == vars[:spatial_thing]["name"]
    end

    test "updates an existing geolocation with a mappable address" do
      user = fake_user!()
      geo = fake_geolocation!(user)

      q = update_geolocation_mutation()
      conn = user_conn(user)

      vars = %{
        spatial_thing:
          Map.merge(geolocation_input(), %{
            "id" => geo.id,
            "mappableAddress" => mappable_address()
          })
      }

      assert updated = grumble_post_key(q, conn, :update_spatial_thing, vars)["spatialThing"]
      assert_geolocation(updated)
      assert geo.lat != updated["lat"]
      assert geo.long != updated["long"]
    end
  end

  describe "delete_geolocation" do
    test "deletes an existing geolocation" do
      user = fake_user!()
      geo = fake_geolocation!(user)

      q = delete_geolocation_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_spatial_thing, %{id: geo.id})
    end

    test "fails to delete a unit of another user unless an admin" do
      q = delete_geolocation_mutation()
      user = fake_user!()
      guest = fake_user!()
      admin = fake_user!(%{is_instance_admin: true})

      geo = fake_geolocation!(user)
      conn = user_conn(guest)
      assert [%{"status" => 403}] = grumble_post_errors(q, conn, %{id: geo.id})
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_spatial_thing, %{id: geo.id})

      # regenerate new to re-delete
      geo = fake_geolocation!(user)
      conn = user_conn(admin)
      assert grumble_post_key(q, conn, :delete_spatial_thing, %{id: geo.id})
    end
  end
end
