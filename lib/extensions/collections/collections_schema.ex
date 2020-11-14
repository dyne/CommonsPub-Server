# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CollectionsSchema do
  @moduledoc """
  GraphQL collection fields, associations, queries and mutations.
  """
  use Absinthe.Schema.Notation

  alias CommonsPub.Web.GraphQL.{
    CommunitiesResolver,
    CollectionsResolver,
    ResourcesResolver,
    CommonResolver,
    FeaturesResolver,
    FlagsResolver,
    FollowsResolver,
    LikesResolver,
    ThreadsResolver,
    UsersResolver,
    UploadResolver
  }

  object :collections_queries do
    @desc "Get a collection by id"
    field :collection, :collection do
      arg(:collection_id, non_null(:string))
      resolve(&CollectionsResolver.collection/2)
    end

    @desc "Get list of collections, most recent activity first"
    field :collections, non_null(:collections_page) do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CollectionsResolver.collections/2)
    end
  end

  object :collections_mutations do
    @desc "Create a collection"
    field :create_collection, :collection do
      arg(:context_id, :string)
      # arg(:community_id, :string)
      arg(:collection, non_null(:collection_input))
      arg(:icon, :upload_input)
      resolve(&CollectionsResolver.create_collection/2)
    end

    @desc "Update a collection"
    field :update_collection, :collection do
      arg(:collection_id, non_null(:string))
      arg(:collection, non_null(:collection_update_input))
      arg(:icon, :upload_input)
      resolve(&CollectionsResolver.update_collection/2)
    end
  end

  @desc """
  A collection is typically the home of resources and discussion threads within a community
  """
  object :collection do
    @desc "An instance-local UUID identifying the user"
    field(:id, non_null(:string))

    @desc "A url for the collection, may be to a remote instance"
    field :canonical_url, :string do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.canonical_url_edge/3)
    end

    @desc "An instance-unique identifier shared with users and communities"
    field :preferred_username, non_null(:string) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.preferred_username_edge/3)
    end

    @desc "A preferred username + the host domain"
    field :display_username, non_null(:string) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.display_username_edge/3)
    end

    @desc "A name field"
    field(:name, non_null(:string))

    @desc "Possibly biographical information"
    field(:summary, :string)

    @desc "An avatar url"
    field :icon, :content do
      resolve(&UploadResolver.icon_content_edge/3)
    end

    @desc "A JSON document containing more info beyond the default fields"
    field(:extra_info, :json)

    @desc "Whether the collection is local to the instance"
    field :is_local, non_null(:boolean) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.is_local_edge/3)
    end

    @desc "Whether the collection is public"
    field :is_public, non_null(:boolean) do
      resolve(&CommonResolver.is_public_edge/3)
    end

    @desc "Whether an instance admin has hidden the collection"
    field :is_disabled, non_null(:boolean) do
      resolve(&CommonResolver.is_disabled_edge/3)
    end

    @desc "When the collection was created"
    field :created_at, non_null(:string) do
      resolve(&CommonResolver.created_at_edge/3)
    end

    @desc "When the collection was last updated"
    field(:updated_at, non_null(:string))

    @desc """
    When the collection or a resource in it was last updated or a
    thread or a comment was created or updated
    """
    field :last_activity, non_null(:string) do
      resolve(&CollectionsResolver.last_activity_edge/3)
    end

    @desc "The current user's like of this collection, if any"
    field :my_like, :like do
      resolve(&LikesResolver.my_like_edge/3)
    end

    @desc "The current user's follow of this collection, if any"
    field :my_follow, :follow do
      resolve(&FollowsResolver.my_follow_edge/3)
    end

    @desc "The current user's flag of the collection, if any"
    field :my_flag, :flag do
      resolve(&FlagsResolver.my_flag_edge/3)
    end

    # @desc "The primary language the community speaks"
    # field :primary_language, :language do
    #   resolve &LocalisationResolver.primary_language/3
    # end

    @desc "The user who created the collection"
    field :creator, :user do
      resolve(&UsersResolver.creator_edge/3)
    end

    @desc "The community the collection belongs to, if any"
    field :community, :community do
      resolve(&CommunitiesResolver.context_community_edge/3)
    end

    @desc "The community or other context the collection belongs to"
    field :context, :any_context do
      resolve(&CommonResolver.context_edge/3)
    end

    @desc "The total number of times this collection has been featured"
    field :feature_count, :integer do
      resolve(&FeaturesResolver.feature_count_edge/3)
    end

    @desc "The total number of resources in the collection, including private ones"
    field :resource_count, :integer do
      resolve(&ResourcesResolver.resource_count_edge/3)
    end

    @desc "The resources in the collection, most recently created last"
    field :resources, :resources_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&ResourcesResolver.resources_edge/3)
    end

    @desc "Total number of followers, including those we can't see"
    field :follower_count, :integer do
      resolve(&FollowsResolver.follower_count_edge/3)
    end

    @desc "Total number of likers, including those we can't see"
    field :liker_count, :integer do
      resolve(&LikesResolver.liker_count_edge/3)
    end

    @desc "Subscriptions users have to the collection"
    field :followers, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&FollowsResolver.followers_edge/3)
    end

    @desc "Likes users have made of the collection"
    field :likers, :likes_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&LikesResolver.likers_edge/3)
    end

    @desc "Flags users have made about the collection, most recently created first"
    field :flags, :flags_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&FlagsResolver.flags_edge/3)
    end

    # @desc "Tags users have applied to the resource, most recently created first"
    # field :taggings, :taggings_page do
    #   arg :limit, :integer
    #   arg :before, list_of(non_null(:cursor))
    #   arg :after, list_of(non_null(:cursor))
    #   resolve &CommonResolver.taggings_edge/3
    # end

    @desc """
    The threads created on the collection, most recently created
    first. Does not include threads created on resources.
    """
    field :threads, :threads_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&ThreadsResolver.threads_edge/3)
    end

    @desc "Activities on the collection, most recent first"
    field :outbox, :activities_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CollectionsResolver.outbox_edge/3)
    end
  end

  object :collections_page do
    field(:page_info, non_null(:page_info))
    field(:edges, non_null(list_of(non_null(:collection))))
    field(:total_count, non_null(:integer))
  end

  input_object :collection_input do
    field(:preferred_username, :string)
    field(:name, non_null(:string))
    field(:summary, :string)
    # field :primary_language_id, :string
    field(:extra_info, :json)
  end

  input_object :collection_update_input do
    field(:name, non_null(:string))
    field(:summary, :string)
    # field :primary_language_id, :string
    field(:extra_info, :json)
  end
end
