# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CommunitiesSchema do
  @moduledoc """
  GraphQL community fields, associations, queries and mutations.
  """
  use Absinthe.Schema.Notation

  alias CommonsPub.Web.GraphQL.{
    CommonResolver,
    CommunitiesResolver,
    CollectionsResolver,
    FlagsResolver,
    FeaturesResolver,
    FollowsResolver,
    LikesResolver,
    ThreadsResolver,
    UsersResolver,
    UploadResolver
  }

  object :communities_queries do
    @desc "Get list of communities, most followed first"
    field :communities, non_null(:communities_page) do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CommunitiesResolver.communities/2)
    end

    @desc "Get a community"
    field :community, :community do
      arg(:community_id, non_null(:string))
      resolve(&CommunitiesResolver.community/2)
    end
  end

  object :communities_mutations do
    @desc "Create a community"
    field :create_community, :community do
      arg(:context_id, :string)
      arg(:community, non_null(:community_input))
      arg(:icon, :upload_input)
      arg(:image, :upload_input)
      resolve(&CommunitiesResolver.create_community/2)
    end

    @desc "Update a community"
    field :update_community, :community do
      arg(:community_id, non_null(:string))
      arg(:community, non_null(:community_update_input))
      arg(:icon, :upload_input)
      arg(:image, :upload_input)
      resolve(&CommunitiesResolver.update_community/2)
    end
  end

  object :community do
    @desc "An instance-local UUID identifying the user"
    field(:id, non_null(:string))

    @desc "A url for the community, may be to a remote instance"
    field :canonical_url, :string do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.canonical_url_edge/3)
    end

    @desc "An instance-unique identifier shared with users and collections"
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

    @desc "A header background image url"
    field :image, :content do
      resolve(&UploadResolver.image_content_edge/3)
    end

    @desc "The parentccommunity or other context the community belongs to"
    field :context, :any_context do
      resolve(&CommonResolver.context_edge/3)
    end

    @desc "A JSON document containing more info beyond the default fields"
    field(:extra_info, :json)

    @desc "Whether the community is local to the instance"
    field :is_local, non_null(:boolean) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.is_local_edge/3)
    end

    @desc "Whether the community has a public profile"
    field :is_public, non_null(:boolean) do
      resolve(&CommonResolver.is_public_edge/3)
    end

    @desc "Whether an instance admin has disabled the community"
    field :is_disabled, non_null(:boolean) do
      resolve(&CommonResolver.is_disabled_edge/3)
    end

    @desc "When the community was created"
    field :created_at, non_null(:string) do
      resolve(&CommonResolver.created_at_edge/3)
    end

    @desc "When the community was last updated"
    field(:updated_at, non_null(:string))

    @desc """
    When the community or a resource or collection in it was last
    updated or a thread or a comment was created or updated
    """
    field :last_activity, non_null(:string) do
      resolve(&CommunitiesResolver.last_activity_edge/3)
    end

    @desc "The current user's like of this community, if any"
    field :my_like, :like do
      resolve(&LikesResolver.my_like_edge/3)
    end

    @desc "The current user's follow of the community, if any"
    field :my_follow, :follow do
      resolve(&FollowsResolver.my_follow_edge/3)
    end

    @desc "The current user's flag of the community, if any"
    field :my_flag, :flag do
      resolve(&FlagsResolver.my_flag_edge/3)
    end

    # @desc "The primary language the community speaks"
    # field :primary_language, :language do
    #   resolve &LocalisationResolver.primary_language/3
    # end

    @desc "The user who created the community"
    field :creator, :user do
      resolve(&UsersResolver.creator_edge/3)
    end

    @desc "The total number of collections in the community, including private ones"
    field :collection_count, :integer do
      resolve(&CollectionsResolver.collection_count_edge/3)
    end

    @desc "The collections in this community"
    field :collections, :collections_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CollectionsResolver.collections_edge/3)
    end

    @desc "The total number of times this community has been featured"
    field :feature_count, :integer do
      resolve(&FeaturesResolver.feature_count_edge/3)
    end

    @desc """
    Threads started on the community, in most recently updated
    order. Does not include threads started on collections or
    resources
    """
    field :threads, :threads_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&ThreadsResolver.threads_edge/3)
    end

    @desc "Total number of followers, including those we can't see"
    field :follower_count, :integer do
      resolve(&FollowsResolver.follower_count_edge/3)
    end

    @desc "Total number of likes, including those we can't see"
    field :liker_count, :integer do
      resolve(&LikesResolver.liker_count_edge/3)
    end

    @desc "Likes users have given the community"
    field :likers, :likes_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&LikesResolver.likers_edge/3)
    end

    @desc "Users following the community, most recently followed first"
    field :followers, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&FollowsResolver.followers_edge/3)
    end

    @desc "Flags users have made about the community, most recently created first"
    field :flags, :flags_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&FlagsResolver.flags_edge/3)
    end

    # @desc "Activities for community moderators. Not available to plebs."
    # field :inbox, non_null(:activities_page) do
    #   arg :limit, :integer
    #   arg :before, :string
    #   arg :after, :string
    #   resolve &CommunitiesResolver.inbox/3
    # end

    @desc "Activities in the community, most recently created first"
    field :outbox, :activities_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CommunitiesResolver.outbox_edge/3)
    end
  end

  object :communities_page do
    field(:page_info, non_null(:page_info))
    field(:edges, non_null(list_of(non_null(:community))))
    field(:total_count, non_null(:integer))
  end

  input_object :community_input do
    field(:preferred_username, :string)
    field(:name, non_null(:string))
    field(:summary, :string)
    # field :primary_language_id, :string
    field(:extra_info, :json)
  end

  input_object :community_update_input do
    field(:name, non_null(:string))
    field(:summary, :string)
    # field :primary_language_id, :string
    field(:extra_info, :json)
  end
end
