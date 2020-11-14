# SPDX-License-Identifier: AGPL-3.0-only
defmodule Organisation.GraphQL.Schema do
  @moduledoc """
  GraphQL organisation fields, associations, queries and mutations.
  """
  use Absinthe.Schema.Notation

  alias CommonsPub.Web.GraphQL.{
    # CommonResolver,
    # FlagsResolver,
    # FollowsResolver,
    # LikesResolver,
    ThreadsResolver
    # UsersResolver,
    # UploadResolver
  }

  # alias CommonsPub.Characters.GraphQL.CommonsPub.Characters.GraphQL.Resolver
  # alias Organisation.GraphQL.Resolver

  object :organisations_queries do
    @desc "Get a organisation by id"
    field :organisation, :organisation do
      arg(:organisation_id, non_null(:string))
      resolve(&Organisation.GraphQL.Resolver.organisation/2)
    end

    @desc "Get list of organisations, most recent activity first"
    field :organisations, non_null(:organisations_page) do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&Organisation.GraphQL.Resolver.organisations/2)
    end
  end

  object :organisations_mutations do
    @desc "Create a organisation"
    field :create_organisation, :organisation do
      arg(:context_id, :string)
      arg(:organisation, non_null(:organisation_input))
      resolve(&Organisation.GraphQL.Resolver.create_organisation/2)
    end

    @desc "Update a organisation"
    field :update_organisation, :organisation do
      arg(:organisation_id, non_null(:string))
      arg(:organisation, non_null(:organisation_update_input))
      resolve(&Organisation.GraphQL.Resolver.update_organisation/2)
    end
  end

  @desc """
  An organisation is an agent/actor that fronts several people/users
  """
  object :organisation do
    @desc "An instance-local UUID identifying the user"
    field(:id, non_null(:string))

    @desc "A JSON document containing more info beyond the default fields"
    field(:extra_info, :json)

    @desc "A name field"
    field(:name, non_null(:string))

    @desc "Possibly biographical information"
    field(:summary, :string)

    @desc "When the organisation was last updated"
    field(:updated_at, non_null(:string))

    @desc "A url for the organisation, may be to a remote instance"
    field(:canonical_url, :string)

    @desc "An instance-unique identifier shared with users and communities"
    field(:preferred_username, :string)

    @desc "The profile associated with this organisation"
    field(:profile, :profile)

    @desc "The character associated with this organisation"
    field(:character, :character)

    @desc "A preferred username + the host domain"
    field :display_username, :string do
      # FIXME
      resolve(&CommonsPub.Characters.GraphQL.Resolver.display_username_edge/3)
    end

    @desc "An avatar url"
    field :icon, :content do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.icon_content_edge/3)
    end

    @desc "Another image url"
    field :image, :content do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.image_content_edge/3)
    end

    @desc "Whether the organisation is local to the instance"
    field :is_local, non_null(:boolean) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.is_local_edge/3)
    end

    @desc "Whether the organisation is public"
    field :is_public, non_null(:boolean) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.is_public_edge/3)
    end

    @desc "Whether an instance admin has hidden the organisation"
    field :is_disabled, non_null(:boolean) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.is_disabled_edge/3)
    end

    # @desc "When the organisation was created"
    # field :created_at, non_null(:string) do
    #   resolve &CommonsPub.Characters.GraphQL.Resolver.created_at_edge/3
    # end

    @desc "The current user's like of this organisation, if any"
    field :my_like, :like do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.my_like_edge/3)
    end

    @desc "The current user's follow of this organisation, if any"
    field :my_follow, :follow do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.my_follow_edge/3)
    end

    @desc "The current user's flag of the organisation, if any"
    field :my_flag, :flag do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.my_flag_edge/3)
    end

    # @desc "The primary language the community speaks"
    # field :primary_language, :language do
    #   resolve &LocalisationResolver.primary_language/3
    # end

    @desc "The user who created the organisation"
    field :creator, :user do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.creator_edge/3)
    end

    @desc "The community the organisation belongs to"
    field :context, :community do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.context_edge/3)
    end

    @desc "Total number of followers, including those we can't see"
    field :follower_count, :integer do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.follower_count_edge/3)
    end

    @desc "Total number of likers, including those we can't see"
    field :liker_count, :integer do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.liker_count_edge/3)
    end

    @desc "Subscriptions users have to the organisation"
    field :followers, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CommonsPub.Characters.GraphQL.Resolver.followers_edge/3)
    end

    @desc "Likes users have made of the organisation"
    field :likers, :likes_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CommonsPub.Characters.GraphQL.Resolver.likers_edge/3)
    end

    @desc "Flags users have made about the organisation, most recently created first"
    field :flags, :flags_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CommonsPub.Characters.GraphQL.Resolver.flags_edge/3)
    end

    # @desc "Tags users have applied to the resource, most recently created first"
    # field :taggings, :taggings_page do
    #   arg :limit, :integer
    #   arg :before, list_of(non_null(:cursor))
    #   arg :after, list_of(non_null(:cursor))
    #   resolve &CommonResolver.taggings_edge/3
    # end

    @desc """
    The threads created on the organisation, most recently created
    first. Does not include threads created on resources.
    """
    field :threads, :threads_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&ThreadsResolver.threads_edge/3)
    end

    @desc "Activities on the organisation, most recent first"
    field :outbox, :activities_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&CommonsPub.Characters.GraphQL.Resolver.outbox_edge/3)
    end
  end

  object :organisations_page do
    field(:page_info, non_null(:page_info))
    field(:edges, non_null(list_of(non_null(:organisation))))
    field(:total_count, non_null(:integer))
  end

  input_object :organisation_input do
    field(:preferred_username, :string)
    field(:name, non_null(:string))
    field(:summary, :string)
    # field :primary_language_id, :string
  end

  input_object :organisation_update_input do
    field(:name, non_null(:string))
    field(:summary, :string)
    # field :primary_language_id, :string
  end
end
