defmodule CommonsPub.Common.Deletion do
  alias CommonsPub.Repo

  alias CommonsPub.Common.DeletionError
  alias CommonsPub.Users.User

  import Logger

  @doc "Find and runs the soft_delete function in the context module based on object type. "
  def trigger_soft_delete(id, current_user) when is_binary(id) do
    with {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: id) do
      trigger_soft_delete(pointer, current_user)
    end
  end

  def trigger_soft_delete(%Pointers.Pointer{} = pointer, current_user) do
    context = CommonsPub.Meta.Pointers.follow!(pointer)
    trigger_soft_delete(context, current_user)
  end

  def trigger_soft_delete(%{} = context, true) do
    do_trigger_soft_delete(%{} = context, %User{})
  end

  def trigger_soft_delete(%{} = context, %{} = current_user) do
    if maybe_allow_delete?(current_user, context) do
      do_trigger_soft_delete(%{} = context, current_user)
    end
  end

  defp do_trigger_soft_delete(%{__struct__: object_type} = context, current_user) do
    with {:error, e} <-
           CommonsPub.Contexts.run_context_function(
             object_type,
             :soft_delete,
             [current_user, context],
             &log_unable/2
           ) do
      CommonsPub.Contexts.run_context_function(
        object_type,
        :soft_delete,
        [context],
        &log_unable/2
      )
    end
  end

  def trigger_soft_delete(context, _, _) do

    log_unable(
      "Object to be deleted not recognised.",
      context
    )
  end

  @spec soft_delete(any()) :: {:ok, any()} | {:error, DeletionError.t()}
  @doc "Just marks an entry as deleted in the database"
  def soft_delete(it), do: deletion_result(do_soft_delete(it))

  @spec soft_delete!(any()) :: any()
  @doc "Marks an entry as deleted in the database or throws a DeletionError"
  def soft_delete!(it), do: deletion_result!(do_soft_delete(it))

  defp do_soft_delete(it), do: Repo.update(CommonsPub.Common.Changeset.soft_delete_changeset(it))

  @spec hard_delete(any()) :: {:ok, any()} | {:error, DeletionError.t()}
  @doc "Actually deletes an entry from the database"
  def hard_delete(it) do
    it
    |> Repo.delete(
      stale_error_field: :id,
      stale_error_message: "has already been deleted"
    )
    |> deletion_result()
  end

  @spec hard_delete!(any()) :: any()
  @doc "Deletes an entry from the database, or throws a DeletionError"
  def hard_delete!(it),
    do: deletion_result!(hard_delete(it))

  # FIXME: boilerplate code, or should this be removed in favour of checking authorisation in contexts?
  defp maybe_allow_delete?(user, context) do
    Map.get(Map.get(user, :local_user, %{}), :is_instance_admin) or
      maybe_creator_allow_delete?(user, context)
  end

  defp maybe_creator_allow_delete?(%{id: user_id}, %{creator_id: creator_id})
       when not is_nil(creator_id) and not is_nil(user_id) do
    creator_id == user_id
  end

  defp maybe_creator_allow_delete?(%{id: user_id}, %{profile: %{creator_id: creator_id}})
       when not is_nil(creator_id) and not is_nil(user_id) do
    creator_id == user_id
  end

  defp maybe_creator_allow_delete?(%{id: user_id}, %{character: %{creator_id: creator_id}})
       when not is_nil(creator_id) and not is_nil(user_id) do
    creator_id == user_id
  end

  # allow to delete self
  defp maybe_creator_allow_delete?(%{id: user_id}, %{id: id})
       when not is_nil(id) and not is_nil(user_id) do
    id == user_id
  end

  defp maybe_creator_allow_delete?(_, _), do: false

  defp deletion_result({:error, e}), do: {:error, DeletionError.new(e)}
  defp deletion_result(other), do: other

  defp deletion_result!({:ok, val}), do: val
  defp deletion_result!({:error, e}), do: throw(e)
  # defp deletion_result!(other), do: other

  defp log_unable(e, args) do
    error = "Unable to delete an object. #{e}"
    Logger.error("#{error} - args: #{inspect(args, pretty: true)}")
    deletion_result({:error, error})
  end

  # ActivityPub incoming Activity: Delete

  def ap_receive_activity(
        %{data: %{"type" => "Delete"}} = _activity,
        %{pointer_id: pointer_id} = _object
      )
      when is_binary(pointer_id) do
    with {:ok, _} <- CommonsPub.Common.Deletion.trigger_soft_delete(pointer_id, true) do
      :ok
    end
  end

  def ap_receive_activity(
        %{data: %{"type" => "Delete"}} = _activity,
        %{} = delete_actor
      ) do
    # IO.inspect(delete: delete_actor)
    with {:ok, character} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(delete_actor),
         {:ok, _} <- CommonsPub.Common.Deletion.trigger_soft_delete(character, true) do
      :ok
    else
      {:error, e} ->
        Logger.warn("Could not find character to delete")
        IO.inspect(delete_actor)
        IO.inspect(CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(delete_actor))
        {:error, e}
    end
  end
end
