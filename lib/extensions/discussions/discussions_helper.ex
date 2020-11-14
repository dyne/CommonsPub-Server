defmodule CommonsPub.Discussions.Web.DiscussionsHelper do
  import CommonsPub.Utils.Web.CommonHelper

  alias CommonsPub.Profiles.Web.ProfilesHelper

  # {:pub_feed_comment, comment}

  @doc """
  Handles a pushed activity from PubSub, by adding it it to the top of timelines
  """
  def pubsub_receive(comment, socket) do
    IO.inspect(pubsub_receive_comment: comment)

    {
      :noreply,
      socket
      |> Phoenix.LiveView.assign(
        :comments,
        Map.merge(socket.assigns.comments, %{comment.id => prepare_comment(comment)})
      )
    }
  end

  def prepare_comments(comments, current_user \\ nil) do
    Enum.map(
      comments,
      &prepare_comment(&1, current_user)
    )
  end

  def prepare_comment(comment, _current_user \\ nil)

  def prepare_comment(%CommonsPub.Threads.Comment{} = comment, _current_user) do
    comment = CommonsPub.Repo.maybe_preload(comment, :creator)

    creator = ProfilesHelper.prepare(comment.creator, %{icon: true, character: true})

    {:ok, from_now} =
      Timex.shift(comment.published_at, minutes: -3)
      |> Timex.format("{relative}", :relative)

    comment
    |> Map.merge(%{published_at: from_now})
    |> Map.merge(%{creator: creator})
    |> Map.merge(%{comments: []})
  end

  def prepare_comment(comment, _) do
    IO.inspect("comment already prepared")
    comment
  end

  def prepare_thread(thread, _with_context) do
    thread =
      if(!is_nil(thread.context_id)) do
        {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: thread.context_id)
        context = CommonsPub.Meta.Pointers.follow!(pointer)
        IO.inspect(context, label: "COPNTEXT")

        context =
          ProfilesHelper.prepare(
            context,
            %{
              icon: true,
              image: true
            },
            150
          )

        thread
        |> Map.merge(%{context: context})
      else
        thread
      end

    prepare_thread(thread)
  end

  def prepare_thread(thread) do
    thread =
      if(!is_nil(thread.context_id)) do
        {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: thread.context_id)
        context = CommonsPub.Meta.Pointers.follow!(pointer)

        thread
        |> Map.merge(%{context: context})
      else
        thread
      end

    thread = CommonsPub.Repo.maybe_preload(thread, :creator)

    creator = ProfilesHelper.prepare(thread.creator, %{icon: true, character: true})

    {:ok, from_now} =
      Timex.shift(thread.published_at, minutes: -3)
      |> Timex.format("{relative}", :relative)

    thread
    |> Map.merge(%{published_at: from_now})
    |> Map.merge(%{creator: creator})
  end

  def build_comment_tree(comments) do
    comments =
      comments
      |> Enum.reverse()
      |> Enum.map(&Map.from_struct/1)

    lum = Enum.reduce(comments, %{}, &Map.put(&2, &1.id, &1))

    # IO.inspect(lum)

    comments
    |> Enum.reduce(lum, fn
      %{reply_to_id: nil} = _comment, acc ->
        acc

      comment, acc ->
        # IO.inspect(acc: acc)
        # IO.inspect(comment: comment)

        acc
        |> update_in([comment.reply_to_id, :comments], &[acc[comment.id] | &1])
        |> Map.delete(comment.id)
    end)
  end
end
