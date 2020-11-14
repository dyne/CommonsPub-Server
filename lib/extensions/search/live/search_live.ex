defmodule CommonsPub.Web.SearchLive do
  use CommonsPub.Web, :live_view

  import CommonsPub.Utils.Web.CommonHelper

  # alias CommonsPub.Web.Component.{
  #   TabNotFoundLive
  # }

  alias CommonsPub.Web.SearchLive.ResultsLive

  def mount(params, session, socket) do
    socket = init_assigns(params, session, socket)
    IO.inspect(params, label: "PARAMS")

    {:ok,
     socket
     |> assign(
       page_title: "Search",
       me: false,
       current_user: socket.assigns.current_user,
       selected_tab: "all",
       search: "",
       hits: [],
       facets: %{},
       num_hits: nil
     )}
  end

  def handle_params(%{"search" => q, "tab" => tab} = _params, _url, socket)
      when q != "" do
    IO.inspect(q, label: "SEARCH")
    IO.inspect(tab, label: "TAB")

    facet_filters =
      if tab != "all" do
        %{"index_type" => tab}
      end

    search = CommonsPub.Search.search(q, nil, ["index_type"], facet_filters)

    IO.inspect(search: search)

    hits =
      if(Map.has_key?(search, "hits") and length(search["hits"])) do
        # search["hits"]
        Enum.map(search["hits"], &search_hit_prepare/1)
        # Enum.filter(hits, & &1)
      end

    # note we only get proper facets when not already faceting
    facets =
      if tab == "all" and Map.has_key?(search, "facetsDistribution") do
        search["facetsDistribution"]
      else
        socket.assigns.facets
      end

    # IO.inspect(hits)

    {:noreply,
     assign(socket,
       selected_tab: tab,
       hits: hits,
       facets: facets,
       num_hits: search["nbHits"],
       search: q

       #  current_user: socket.assigns.current_user
     )}
  end

  def handle_params(%{"tab" => tab} = _params, _url, socket) do
    IO.inspect(tab, label: "TAB")

    {:noreply,
     assign(socket,
       selected_tab: tab
       #  current_user: socket.assigns.current_user
     )}
  end

  def handle_params(_params, _url, socket) do
    # community =
    # CommunitiesHelper.community_load(socket, params, %{icon: true, image: true, character: true})

    # IO.inspect(community, label: "community")

    {:noreply,
     assign(socket,
       #  community: community,
       current_user: socket.assigns.current_user
     )}
  end

  defp link_body(name, icon) do
    assigns = %{name: name, icon: icon}

    ~L"""
      <i class="<%= @icon %>"></i>
      <%= @name %>
    """
  end

  def search_hit_prepare(hit) do
    # is this safe?
    hit |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end
end
