defmodule CommonsPub.Activities.Web.ActivitiesHelper do
  import CommonsPub.Utils.Web.CommonHelper

  alias CommonsPub.Profiles.Web.ProfilesHelper

  @doc """
  Forward PubSub activities in timeline to our timeline component
  """
  def pubsub_activity_forward(activity, module, timeline_component_id, socket) do
    # IO.inspect(pubsub_activity_forward: activity)

    Phoenix.LiveView.send_update(module,
      id: timeline_component_id,
      activity: activity
    )

    {:noreply, socket}
  end

  @doc """
  Handles a pushed activity from PubSub, by adding it it to the top of timelines
  """
  def pubsub_receive(activity, socket) do
    # IO.inspect(pubsub_receive: activity)

    {
      :ok,
      socket
      |> Phoenix.LiveView.assign(:activities, Enum.concat([activity], socket.assigns.activities))
    }
  end

  def outbox_live({feed_id_func, feed_param}, feed_tables, assigns, socket)
      when is_function(feed_id_func) do
    feed_id = Map.get(assigns, :feed_id) || feed_id_func.(feed_param)
    outbox_live(feed_id, feed_tables, assigns, socket)
  end

  def outbox_live(feed_id_func, feed_tables, assigns, socket) when is_function(feed_id_func) do
    feed_id = Map.get(assigns, :feed_id) || feed_id_func.()
    outbox_live(feed_id, feed_tables, assigns, socket)
  end

  def outbox_live(feed_id, feed_tables_func, assigns, socket)
      when is_function(feed_tables_func) do
    feed_tables = Map.get(assigns, :feed_tables) || feed_tables_func.()
    outbox_live(feed_id, feed_tables, assigns, socket)
  end

  def outbox_live(feed_id, feed_tables, assigns, socket) when is_binary(feed_id) do
    {:ok, box} =
      CommonsPub.Web.GraphQL.ActivitiesResolver.fetch_outbox_edge(
        feed_id,
        feed_tables,
        %{after: assigns.after, limit: 10}
      )

    # subscribe to the feed for realtime updates
    CommonsPub.Utils.Web.CommonHelper.pubsub_subscribe(feed_id, socket)

    # IO.inspect(box: box)

    activities_live_output(box, feed_id, feed_tables, assigns, socket)
  end

  def outbox_live(_feed_id_missing, feed_tables, assigns, socket) do
    activities_live_output(nil, nil, feed_tables, assigns, socket)
  end

  def activities_live_output(box, feed_id, feed_tables, assigns, socket) do
    activities =
      if is_map(box) and length(box.edges) do
        Enum.concat(assigns.activities, box.edges)
      else
        assigns.activities
      end

    Phoenix.LiveView.assign(socket,
      activities: activities,
      feed_id: feed_id,
      feed_tables: feed_tables,
      has_next_page: e(box, :page_info, :has_next_page, nil),
      after: e(box, :page_info, :end_cursor, nil),
      before: e(box, :page_info, :start_cursor, nil),
      current_user: assigns.current_user
    )
  end

  def inbox_live(user, assigns, socket) do
    # user inbox feed
    inbox_id = Map.get(assigns, :feed_id) || CommonsPub.Feeds.inbox_id(user)
    # IO.inspect(inbox_live: inbox_id)

    # feeds the user is subscribed to
    feed_ids = CommonsPub.Web.GraphQL.UsersResolver.user_inbox_feeds(user, inbox_id)
    # IO.inspect(feed_ids: feed_ids)

    # IO.inspect(inbox_feed_ids: feed_ids)
    CommonsPub.Utils.Web.CommonHelper.pubsub_subscribe(feed_ids, socket)

    # what to include
    feed_tables =
      Map.get(assigns, :feed_tables) || CommonsPub.Users.default_inbox_query_contexts()

    {:ok, box} =
      CommonsPub.Web.GraphQL.UsersResolver.fetch_feeds_edge(
        %{after: assigns.after, limit: 10},
        feed_ids,
        feed_tables
      )

    activities_live_output(box, inbox_id, feed_tables, assigns, socket)
  end

  def prepare(%{display_verb: _, display_object: _} = activity, _current_user) do
    IO.inspect("activity already prepared")
    activity
  end

  def prepare(%{:__struct__ => _} = activity, current_user) do
    activity = CommonsPub.Repo.maybe_preload(activity, [:creator, :context])

    prepare_activity(activity, current_user)
  end

  def prepare(activity, current_user) do
    prepare_activity(activity, current_user)
  end

  defp prepare_parent_context(%{context: %{thread_id: thread_id} = _context} = activity)
       when not is_nil(thread_id) do
    activity = CommonsPub.Repo.maybe_preload(activity, context: [:thread])

    activity
    |> Map.merge(%{
      context:
        Map.merge(
          activity.context,
          %{context: CommonsPub.Contexts.prepare_context(activity.context.thread)}
        )
    })
  end

  defp prepare_parent_context(%{context: %{} = context} = activity) do
    activity
    |> Map.merge(%{context: CommonsPub.Contexts.prepare_context(context)})
  end

  defp prepare_parent_context(activity) do
    activity
  end

  defp prepare_activity(activity, _current_user) do
    # guess what type of thing we're dealing with
    activity = CommonsPub.Contexts.prepare_context(activity)

    activity = prepare_parent_context(activity)

    # get the OP
    creator = ProfilesHelper.prepare(activity.creator, %{icon: true, character: true})

    # IO.inspect(activity.published_at)

    # a friendly date
    from_now = activity_date_from_now(activity)

    # IO.inspect(preparing_activity: activity)

    activity
    |> Map.merge(%{published_at: from_now})
    |> Map.merge(%{creator: creator})
    |> Map.merge(%{display_verb: display_activity_verb(activity)})
    |> Map.merge(%{display_object: display_activity_object(activity)})
    |> Map.merge(%{display_object_context: display_object_context(Map.get(activity, :context))})
    |> Map.merge(%{activity_url: activity_url(activity)})
  end

  def activity_date_from_now(activity) do
    if Map.has_key?(activity, :published_at) and strlen(activity.published_at) > 0 do
      date_from_now(activity.published_at)
    else
      if Map.has_key?(activity, :updated_at) and strlen(activity.updated_at) > 0,
        do: date_from_now(activity.updated_at)
    end
  end

  def activity_url(
        %{
          context: %Ecto.Association.NotLoaded{}
        } = activity
      ) do
    activity = CommonsPub.Repo.maybe_preload(activity, :context)
    activity_url(activity)
  end

  def activity_url(%{
        context: %{} = context
      }) do
    object_url(context)
  end

  def activity_url(%{} = activity) do
    object_url(activity)
  end

  def display_activity_verb(%{display_verb: display_verb}) when not is_nil(display_verb) do
    display_verb
  end

  def display_activity_verb(%CommonsPub.Likes.Like{}) do
    "favourited"
  end

  def display_activity_verb(%CommonsPub.Threads.Comment{}) do
    "posted"
  end

  def display_activity_verb(%{verb: verb, context_type: context_type} = activity)
      when not is_nil(verb) and not is_nil(context_type) do
    cond do
      context_type == "flag" ->
        "flagged:"

      context_type == "like" ->
        "favourited"

      context_type == "follow" ->
        "followed"

      context_type == "resource" ->
        "added"

      context_type == "comment" ->
        cond do
          !is_nil(activity.context.reply_to_id) and !is_nil(activity.context.name) ->
            "replied to:"

          activity.context.reply_to_id ->
            "replied to"

          Map.has_key?(activity.context, :name) and strlen(activity.context.name) > 0 ->
            "posted:"

          Map.has_key?(activity.context, :message) and strlen(activity.context.message) > 0 ->
            "said:"

          true ->
            "started"
        end

      verb == "created" ->
        "created"

      verb == "updated" ->
        "updated"

      true ->
        "acted on"
    end
  end

  def display_activity_verb(%{verb: verb}) when not is_nil(verb) do
    verb
  end

  def display_activity_verb(%{context_type: context_type}) when not is_nil(context_type) do
    "acted on"
  end

  def display_activity_verb(_) do
    "did"
  end

  def display_activity_object(%{verb: verb, context_type: context_type} = activity)
      when not is_nil(verb) and not is_nil(context_type) do
    cond do
      context_type == "comment" ->
        cond do
          activity.context.name ->
            activity.context.name

          true ->
            "a discussion"
        end

      context_type == "like" ->
        ""

      context_type == "resource" ->
        "a " <> context_type <> " "

      Map.has_key?(activity.context, :name) and strlen(activity.context.name) > 0 ->
        "a " <> context_type

      # <> ": " <> activity.context.name

      Map.has_key?(activity.context, :message) and strlen(activity.context.message) > 0 ->
        "«" <> activity.context.message <> "»"

      true ->
        "a " <> context_type
    end
  end

  def display_activity_object(%{context_type: context_type}) when not is_nil(context_type) do
    "a " <> context_type
  end

  def display_activity_object(_) do
    "something"
  end

  def display_object_context(%{
        context: %CommonsPub.Threads.Thread{} = parent_context
      }) do
    display_object_context(parent_context)
  end

  def display_object_context(%{context: %{name: name} = parent_context})
      when not is_nil(name) do
    # IO.inspect(parent_context: parent_context)
    # TODO: remove hacky HTML
    "in <a data-phx-link='redirect' data-phx-link-state='push' href='#{object_url(parent_context)}'>#{
      name
    }</a>"
  end

  def display_object_context(_activity) do
    # IO.inspect(display_object_context: activity)

    ""
  end
end
