defmodule Pleroma.Object do
  # This should be Pleroma.ActivityStream.Object
  #
  # FIXME
  # * It should not use Repo in this module
  # * I'd move query functions to a new module Pleroma.ActivityStream.ObjectQueries
  use Ecto.Schema
  alias Pleroma.{Repo, Object}
  import Ecto.{Query, Changeset}

  schema "objects" do
    field(:data, :map)

    timestamps()
  end

  def create(data) do
    Object.change(%Object{}, %{data: data})
    |> Repo.insert()
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :objects_unique_apid_index)
  end

  # This should be a secondary function
  def get_by_ap_id(nil), do: nil

  # Should we check if ap_id is binary?
  def get_by_ap_id(ap_id) do
    Repo.one(from(object in Object, where: fragment("(?)->>'id' = ?", object.data, ^ap_id)))
  end

  # IMPORTANT
  # So normalize it is just find local copy by id, strange
  # I need more info to resolve this
  # This is very used
  def normalize(obj) when is_map(obj), do: Object.get_by_ap_id(obj["id"])
  def normalize(ap_id) when is_binary(ap_id), do: Object.get_by_ap_id(ap_id)
  def normalize(_), do: nil

  # This should be the default function
  def get_cached_by_ap_id(ap_id) do
    # FIXME Bad practice, we should never check the current environment
    if Mix.env() == :test do
      get_by_ap_id(ap_id)
    else
      key = "object:#{ap_id}"

      Cachex.fetch!(:user_cache, key, fn _ ->
        object = get_by_ap_id(ap_id)

        if object do
          {:commit, object}
        else
          {:ignore, object}
        end
      end)
    end
  end

  # What?
  def context_mapping(context) do
    Object.change(%Object{}, %{data: %{"id" => context}})
  end
end
