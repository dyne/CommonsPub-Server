defmodule Geolocation.Simulate do
  import CommonsPub.Utils.Simulation

  alias Geolocation.Geolocations

  def mappable_address do
    # guaranteed random
    "1221 Williamson St., Madison, WI 53703"
  end

  def geolocation(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:lat, &Faker.Address.latitude/0)
    |> Map.put_new_lazy(:long, &Faker.Address.longitude/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
    |> Map.merge(character(base))
  end

  def geolocation_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)
    |> Map.put_new_lazy("lat", &Faker.Address.latitude/0)
    |> Map.put_new_lazy("long", &Faker.Address.longitude/0)
    |> Map.put_new_lazy("alt", &pos_integer/0)
  end

  def fake_geolocation!(user \\ nil, context \\ nil, overrides \\ %{})

  def fake_geolocation!(user, context, overrides) when is_nil(context) do
    {:ok, geolocation} = Geolocations.create(user, geolocation(overrides))
    geolocation
  end

  def fake_geolocation!(user, context, overrides) do
    {:ok, geolocation} = Geolocations.create(user, context, geolocation(overrides))
    geolocation
  end
end
