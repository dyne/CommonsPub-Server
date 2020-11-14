# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Schema do
  @moduledoc "Root GraphQL Schema"
  use Absinthe.Schema

  require Logger

  alias CommonsPub.Web.GraphQL.SchemaUtils
  alias CommonsPub.Web.GraphQL.Middleware.CollapseErrors
  alias Absinthe.Middleware.{Async, Batch}

  # @pipeline_modifier OverridePhase

  def plugins, do: [Async, Batch]

  def middleware(middleware, _field, _object) do
    # [{CommonsPub.Web.GraphQL.Middleware.Debug, :start}] ++
    middleware ++ [CollapseErrors]
  end

  import_types(CommonsPub.Web.GraphQL.AccessSchema)
  import_types(CommonsPub.Web.GraphQL.ActivitiesSchema)
  import_types(CommonsPub.Web.GraphQL.AdminSchema)
  import_types(CommonsPub.Web.GraphQL.BlocksSchema)
  import_types(CommonsPub.Web.GraphQL.CollectionsSchema)
  import_types(CommonsPub.Web.GraphQL.CommentsSchema)
  import_types(CommonsPub.Web.GraphQL.CommonSchema)
  import_types(CommonsPub.Web.GraphQL.CommunitiesSchema)
  import_types(CommonsPub.Web.GraphQL.Cursor)
  import_types(CommonsPub.Web.GraphQL.FeaturesSchema)
  import_types(CommonsPub.Web.GraphQL.FlagsSchema)
  import_types(CommonsPub.Web.GraphQL.FollowsSchema)
  import_types(CommonsPub.Web.GraphQL.InstanceSchema)
  import_types(CommonsPub.Web.GraphQL.JSON)
  import_types(CommonsPub.Web.GraphQL.LikesSchema)
  import_types(CommonsPub.Web.GraphQL.MiscSchema)
  import_types(CommonsPub.Web.GraphQL.ResourcesSchema)
  import_types(CommonsPub.Web.GraphQL.ThreadsSchema)
  import_types(CommonsPub.Web.GraphQL.UsersSchema)
  import_types(CommonsPub.Web.GraphQL.UploadSchema)

  # Extension Modules
  import_types(CommonsPub.Profiles.GraphQL.Schema)
  import_types(CommonsPub.Characters.GraphQL.Schema)
  import_types(Organisation.GraphQL.Schema)
  import_types(CommonsPub.Locales.GraphQL.Schema)
  import_types(CommonsPub.Tag.GraphQL.TagSchema)
  import_types(Taxonomy.GraphQL.TaxonomySchema)
  import_types(Measurement.Unit.GraphQL)
  import_types(Geolocation.GraphQL)
  import_types(ValueFlows.Schema)

  query do
    import_fields(:access_queries)
    import_fields(:activities_queries)
    import_fields(:blocks_queries)
    import_fields(:collections_queries)
    import_fields(:comments_queries)
    import_fields(:common_queries)
    import_fields(:communities_queries)
    import_fields(:features_queries)
    import_fields(:flags_queries)
    import_fields(:follows_queries)
    import_fields(:instance_queries)
    import_fields(:likes_queries)
    import_fields(:resources_queries)
    import_fields(:threads_queries)
    import_fields(:users_queries)

    # Extension Modules
    import_fields(:profile_queries)
    import_fields(:character_queries)
    import_fields(:organisations_queries)
    import_fields(:tag_queries)

    # Taxonomy
    import_fields(:locales_queries)
    import_fields(:taxonomy_queries)

    # ValueFlows
    import_fields(:measurement_query)
    import_fields(:geolocation_query)
    import_fields(:value_flows_query)
    # import_fields(:value_flows_extra_queries)
  end

  mutation do
    import_fields(:access_mutations)
    import_fields(:admin_mutations)
    import_fields(:blocks_mutations)
    import_fields(:collections_mutations)
    import_fields(:comments_mutations)
    import_fields(:common_mutations)
    import_fields(:communities_mutations)
    import_fields(:features_mutations)
    import_fields(:flags_mutations)
    import_fields(:follows_mutations)
    import_fields(:likes_mutations)
    import_fields(:resources_mutations)
    import_fields(:threads_mutations)
    import_fields(:users_mutations)

    # Extension Modules
    import_fields(:profile_mutations)
    import_fields(:character_mutations)
    import_fields(:organisations_mutations)
    import_fields(:tag_mutations)
    import_fields(:taxonomy_mutations)
    # ValueFlows
    import_fields(:geolocation_mutation)
    import_fields(:measurement_mutation)
    import_fields(:value_flows_mutation)

    @desc "Fetch metadata from webpage"
    field :fetch_web_metadata, :web_metadata do
      arg(:url, non_null(:string))
      resolve(&CommonsPub.Web.GraphQL.MiscSchema.fetch_web_metadata/2)
    end

    # for debugging purposes only:
    # @desc "Fetch an AS2 object from URL"
    # field :fetch_object, type: :fetched_object do
    #   arg :url, non_null(:string)
    #   resolve &CommonsPub.Web.GraphQL.MiscSchema.fetch_object/2
    # end
  end

  @doc """
  hydrate SDL schema with resolvers
  """
  def hydrate(%Absinthe.Blueprint{}, _) do
    SchemaUtils.hydrations_merge([
      &Geolocation.GraphQL.Hydration.hydrate/0,
      &Measurement.Hydration.hydrate/0,
      &ValueFlows.Hydration.hydrate/0
    ])
  end

  # hydrations fallback
  def hydrate(_node, _ancestors) do
    []
  end

  union :any_context do
    description("Any type of known object")

    # TODO: autogenerate

    # types(SchemaUtils.context_types)

    types([
      :community,
      :collection,
      :resource,
      :comment,
      :flag,
      :follow,
      :like,
      :user,
      :organisation,
      :category,
      :taggable,
      :spatial_thing,
      :intent
    ])

    resolve_type(fn
      %CommonsPub.Users.User{}, _ ->
        :user

      %CommonsPub.Communities.Community{}, _ ->
        :community

      %CommonsPub.Collections.Collection{}, _ ->
        :collection

      %CommonsPub.Resources.Resource{}, _ ->
        :resource

      %CommonsPub.Threads.Thread{}, _ ->
        :thread

      %CommonsPub.Threads.Comment{}, _ ->
        :comment

      %CommonsPub.Follows.Follow{}, _ ->
        :follow

      %CommonsPub.Likes.Like{}, _ ->
        :like

      %CommonsPub.Flags.Flag{}, _ ->
        :flag

      %CommonsPub.Features.Feature{}, _ ->
        :feature

      %Organisation{}, _ ->
        :organisation

      %Geolocation{}, _ ->
        :spatial_thing

      %CommonsPub.Tag.Category{}, _ ->
        :category

      %CommonsPub.Tag.Taggable{}, _ ->
        :taggable

      # %ValueFlows.Agent.Agents{}, _ -> :agent
      # %ValueFlows.Agent.People{}, _ -> :person
      # %ValueFlows.Agent.Organizations{}, _ -> :organization
      %ValueFlows.Planning.Intent{}, _ ->
        :intent

      o, _ ->
        Logger.warn("Any context resolved to an unknown type: #{inspect(o, pretty: true)}")
    end)
  end
end
