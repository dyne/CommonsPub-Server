# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.UsersSchema do
  use Absinthe.Schema.Notation

  alias CommonsPub.Web.GraphQL.{
    CommonResolver,
    FlagsResolver,
    FollowsResolver,
    LikesResolver,
    UsersResolver,
    UploadResolver
  }

  object :users_queries do
    @desc "Check if a user exists with a username"
    field :username_available, non_null(:boolean) do
      arg(:username, non_null(:string))
      resolve(&UsersResolver.username_available/2)
    end

    @desc "Get my user"
    field :me, :me do
      resolve(&UsersResolver.me/2)
    end

    @desc "Get a user, by either username or ID"
    field :user, :user do
      arg(:user_id, :string)
      arg(:username, :string)
      resolve(&UsersResolver.user/2)
    end

    @desc "Get list of known users"
    field :users, non_null(:users_page) do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.users/2)
    end
  end

  object :auth_payload do
    field(:token, non_null(:string))

    field :me, non_null(:me) do
      resolve(&UsersResolver.me/3)
    end
  end

  object :users_mutations do
    @desc "Create a user"
    field :create_user, :me do
      arg(:user, non_null(:registration_input))
      arg(:icon, :upload_input)
      arg(:image, :upload_input)
      resolve(&UsersResolver.create_user/2)
    end

    @desc "Update a profile"
    field :update_profile, :me do
      arg(:profile, non_null(:update_profile_input))
      arg(:icon, :upload_input)
      arg(:image, :upload_input)
      resolve(&UsersResolver.update_profile/2)
    end

    @desc "Reset password request"
    field :reset_password_request, :boolean do
      arg(:email, non_null(:string))
      resolve(&UsersResolver.reset_password_request/2)
    end

    @desc "Reset password"
    field :reset_password, :auth_payload do
      arg(:token, non_null(:string))
      arg(:password, non_null(:string))
      resolve(&UsersResolver.reset_password/2)
    end

    @desc "Confirm email. Returns a login token."
    field :confirm_email, :auth_payload do
      arg(:token, non_null(:string))
      resolve(&UsersResolver.confirm_email/2)
    end

    @desc "Log in, works with both username and email"
    field :create_session, :auth_payload do
      @desc "This field is deprecated, please use `login` instead"
      arg(:email, :string)
      @desc "Username or email"
      arg(:login, :string)
      @desc "Password in cleartext"
      arg(:password, non_null(:string))
      resolve(&UsersResolver.create_session/2)
    end

    @desc "Log out"
    field :delete_session, :boolean do
      resolve(&UsersResolver.delete_session/2)
    end

    @desc "Deletes my account!"
    field :delete_self, :boolean do
      arg(:i_am_sure, non_null(:boolean))
      resolve(&UsersResolver.delete/2)
    end
  end

  @desc """
  The current user. Contains more information than just the `user` type
  """
  object :me do
    @desc "The public info"
    field :user, non_null(:user) do
      resolve(&UsersResolver.user_edge/3)
    end

    @desc "The user's email"
    field :email, non_null(:string) do
      resolve(&UsersResolver.email_edge/3)
    end

    @desc "Would the user like to receive digest emails of updates?"
    field :wants_email_digest, non_null(:boolean) do
      resolve(&UsersResolver.wants_email_digest_edge/3)
    end

    @desc "Does the user want notifications? Which don't work yet."
    field :wants_notifications, non_null(:boolean) do
      resolve(&UsersResolver.wants_notifications_edge/3)
    end

    @desc "Has the user confirmed their account?"
    field :is_confirmed, non_null(:boolean) do
      resolve(&UsersResolver.is_confirmed_edge/3)
    end

    @desc "Is the user a witch or wizard?"
    field :is_instance_admin, non_null(:boolean) do
      resolve(&UsersResolver.is_instance_admin_edge/3)
    end


  end



  @desc "User profile information"
  object :user do
    @desc "An instance-local ULID identifying the user"
    field(:id, non_null(:id))

    @desc "A url for the user, may be to a remote instance"
    field :canonical_url, :string do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.canonical_url_edge/3)
    end

    @desc "An instance-unique identifier shared with communities and collections"
    field :preferred_username, non_null(:string) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.preferred_username_edge/3)
    end

    @desc "A preferred username + the host domain"
    field :display_username, non_null(:string) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.display_username_edge/3)
    end

    @desc "A name field"
    field(:name, :string)
    @desc "Possibly biographical information"
    field(:summary, :string)
    @desc "Free text"
    field(:location, :string)
    @desc "A valid URL"
    field(:website, :string)

    @desc "A JSON document containing more info beyond the default fields"
    field(:extra_info, :json)

    @desc "An avatar url"
    field :icon, :content do
      resolve(&UploadResolver.icon_content_edge/3)
    end

    @desc "A header background image url"
    field :image, :content do
      resolve(&UploadResolver.image_content_edge/3)
    end

    @desc "Whether the user is local to the instance"
    field :is_local, non_null(:boolean) do
      resolve(&CommonsPub.Characters.GraphQL.Resolver.is_local_edge/3)
    end

    @desc "Whether the user has a public profile"
    field :is_public, non_null(:boolean) do
      resolve(&CommonResolver.is_public_edge/3)
    end

    @desc "Whether an instance admin has disabled the user's account"
    field :is_disabled, non_null(:boolean) do
      resolve(&CommonResolver.is_disabled_edge/3)
    end

    @desc "When the user signed up"
    field :created_at, non_null(:string) do
      resolve(&CommonResolver.created_at_edge/3)
    end

    @desc "When the user last updated their profile"
    field(:updated_at, non_null(:string))
    @desc "The last time the user did anything"
    field :last_activity, :string do
      resolve(&UsersResolver.last_activity_edge/3)
    end

    @desc "The current user's follow of this user, if any"
    field :my_follow, :follow do
      resolve(&FollowsResolver.my_follow_edge/3)
    end

    @desc "The current user's like of this user, if any"
    field :my_like, :like do
      resolve(&LikesResolver.my_like_edge/3)
    end

    @desc "The current user's flag of this user, if any"
    field :my_flag, :flag do
      resolve(&FlagsResolver.my_flag_edge/3)
    end

    # @desc "The language the user wishes to use the app in"
    # field :primary_language, :language do
    #   resolve &LocalisationResolver.primary_language/3
    # end

    @desc "Total number of things the user follows, including privately"
    field :follow_count, :integer do
      resolve(&FollowsResolver.follow_count_edge/3)
    end

    @desc "Total number of followers, including private follows"
    field :follower_count, :integer do
      resolve(&FollowsResolver.follower_count_edge/3)
    end

    @desc "Total number of likes, including those we can't see"
    field :like_count, :integer do
      resolve(&LikesResolver.like_count_edge/3)
    end

    @desc "Total number of likers, including those we can't see"
    field :liker_count, :integer do
      resolve(&LikesResolver.liker_count_edge/3)
    end

    @desc "Subscriptions users have to the collection"
    field :follows, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&FollowsResolver.follows_edge/3)
    end

    @desc "Subscriptions users have to the collection"
    field :followers, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&FollowsResolver.followers_edge/3)
    end

    @desc "The collections a user is following, most recently followed first"
    field :collection_follows, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.collection_follows_edge/3)
    end

    @desc "The communities a user is following, most recently followed first"
    field :community_follows, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.community_follows_edge/3)
    end

    @desc "The users a user is following, most recently followed first"
    field :user_follows, :follows_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.user_follows_edge/3)
    end

    @desc "The likes a user has created"
    field :likes, :likes_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&LikesResolver.likes_edge/3)
    end

    @desc "The likes a user has from other people"
    field :likers, :likes_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&LikesResolver.likers_edge/3)
    end

    @desc "Comments the user has made, most recently created first"
    field :comments, :comments_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.comments_edge/3)
    end

    @desc "Activities of the user, most recently created first"
    field :outbox, :activities_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.outbox_edge/3)
    end

    @desc """
    Activities of others the user is following, most recently created
    first. Only available to the current user under `me`
    """
    field :inbox, :activities_page do
      arg(:limit, :integer)
      arg(:before, list_of(non_null(:cursor)))
      arg(:after, list_of(non_null(:cursor)))
      resolve(&UsersResolver.inbox_edge/3)
    end

    #   @desc "Taggings the user has created"
    #   field :tagged, :taggings_page do
    #     arg :limit, :integer
    #     arg :before, list_of(non_null(:cursor))
    #     arg :after, list_of(non_null(:cursor))
    #     resolve &CommonResolver.tagged/3
    #   end
  end

  input_object :registration_input do
    field(:email, non_null(:string))
    field(:password, non_null(:string))
    field(:preferred_username, non_null(:string))
    field(:name, non_null(:string))
    field(:summary, :string)
    field(:location, :string)
    field(:website, :string)
    # field :primary_language_id, :string
    field(:wants_email_digest, non_null(:boolean))
    field(:wants_notifications, non_null(:boolean))
    field(:extra_info, :json)
  end

  input_object :update_profile_input do
    field(:email, :string)
    field(:name, :string)
    field(:summary, :string)
    field(:location, :string)
    field(:website, :string)
    # field :primary_language_id, :string
    field(:wants_email_digest, :boolean)
    field(:wants_notifications, :boolean)
    field(:extra_info, :json)
  end

  input_object :login_input do
    field(:email, non_null(:string))
    field(:password, non_null(:string))
  end

  object :users_page do
    field(:page_info, non_null(:page_info))
    field(:edges, non_null(list_of(non_null(:user))))
    field(:total_count, non_null(:integer))
  end
end
