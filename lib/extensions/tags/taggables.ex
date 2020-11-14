defmodule CommonsPub.Tag.Taggables do
  # import Ecto.Query
  # alias Ecto.Changeset

  alias CommonsPub.{
    # Common,
    # GraphQL,
    Repo
    # GraphQL.Page,
    # Contexts
  }

  # alias CommonsPub.Users.User
  alias CommonsPub.Tag.Taggable
  alias CommonsPub.Tag.Taggable.Queries

  # alias CommonsPub.Characters

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  def one(filters), do: Repo.single(Queries.query(Taggable, filters))

  def get(id) do
    if CommonsPub.Common.is_ulid(id) do
      one(id: id)
    else
      one(username: id)
    end
  end

  # def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Taggable, filters))}

  def prefix("Community") do
    "&"
  end

  def prefix("User") do
    "@"
  end

  def prefix(_) do
    "+"
  end

  ## mutations

  @doc """
  Create a Taggable that makes an existing object (eg. Geolocation) taggable
  """
  def maybe_make_taggable(user, id, _) when is_number(id) do
    with {:ok, t} <- maybe_taxonomy_tag(user, id) do
      {:ok, t}
    else
      _e ->
        {:error, "Please provide a pointer"}
    end
  end

  def maybe_make_taggable(user, pointer_id, attrs) when is_binary(pointer_id) do
    if CommonsPub.Utils.Web.CommonHelper.is_numeric(pointer_id) do
      maybe_make_taggable(user, String.to_integer(pointer_id), attrs)
    else
      with {:ok, taggable} <- get(pointer_id) do
        {:ok, taggable}
      else
        _e ->
          with {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: pointer_id) do
            maybe_make_taggable(user, pointer, attrs)
          end
      end
    end
  end

  def maybe_make_taggable(user, %Pointers.Pointer{} = pointer, attrs) do
    with context = CommonsPub.Meta.Pointers.follow!(pointer) do
      maybe_make_taggable(user, context, attrs)
    end
  end

  def maybe_make_taggable(user, %{} = context, attrs) do
    with {:ok, taggable} <- one(id: context.id) do
      {:ok, taggable}
    else
      _e -> make_taggable(user, context, attrs)
    end
  end

  def maybe_make_taggable(user, context) do
    maybe_make_taggable(user, context, %{})
  end

  @doc """
  Create a taggable mixin for an existing poitable object (please use maybe_make_taggable instead)
  """
  def make_taggable(_creator, %{} = pointable_obj, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      # TODO: check that the taggable doesn't already exist (same name and parent)

      with {:ok, attrs} <- attrs_with_taggable(attrs, pointable_obj),
           {:ok, taggable} <- insert_taggable(attrs) do
        {:ok, taggable}
      end
    end)
  end

  defp attrs_with_taggable(%{facet: facet} = attrs, %{} = pointable_obj) when not is_nil(facet) do
    attrs = Map.put(attrs, :prefix, prefix(attrs.facet))
    attrs = Map.put(attrs, :id, pointable_obj.id)
    # IO.inspect(attrs)
    {:ok, attrs}
  end

  defp attrs_with_taggable(attrs, %{} = pointable_obj) do
    attrs_with_taggable(
      Map.put(
        attrs,
        :facet,
        pointable_obj.__struct__ |> to_string() |> String.split(".") |> List.last()
      ),
      pointable_obj
    )
  end

  defp insert_taggable(attrs) do
    # IO.inspect(insert_taggable: attrs)
    cs = Taggable.create_changeset(attrs)
    with {:ok, taggable} <- Repo.insert(cs), do: {:ok, taggable}
  end

  # TODO: take the user who is performing the update
  def update(_user, %Taggable{} = taggable, attrs) do
    Repo.transact_with(fn ->
      # :ok <- publish(taggable, :updated)
      with {:ok, taggable} <- Repo.update(Taggable.update_changeset(taggable, attrs)) do
        {:ok, taggable}
      end
    end)
  end


  def maybe_taxonomy_tag(user, id) do
    if CommonsPub.Config.module_enabled?(Taxonomy.TaxonomyTags) do
      Taxonomy.TaxonomyTags.maybe_make_category(user, id)
    end
  end
end
