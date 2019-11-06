# MoodleNet: Connecting and empowering educators worldwide
# Copyright © 2018-2019 Moodle Pty Ltd <https://moodle.com/moodlenet/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule MoodleNet.Actors.Actor do
  use MoodleNet.Common.Schema
  import MoodleNet.Common.Changeset,
    only: [meta_pointer_constraint: 1, change_public: 1, validate_language_code: 2]
  alias Ecto.Changeset
  alias MoodleNet.{Localisation, Meta}
  alias MoodleNet.Actors.{Actor, ActorRevision, ActorLatestRevision}
  alias MoodleNet.Localisation.Language
  alias MoodleNet.Meta.Pointer

  alias MoodleNet.Peers.Peer

  # TODO: match the agreed rules
  @username_regex ~r([a-zA-Z0-9]+)

  meta_schema "mn_actor" do
    belongs_to :peer, MoodleNet.Peers.Peer
    belongs_to :alias, Pointer
    has_many :revisions, ActorRevision
    has_one :latest_revision, ActorLatestRevision
    has_one :current, through: [:latest_revision, :revision] # poke through to revision itself
    field :preferred_username, :string
    belongs_to :primary_language, Language, type: :string
    field :signing_key, :string
    field :is_public, :boolean, virtual: true
    field :published_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec
    timestamps()
  end

  @doc "Inflates the language (for (almost) free)"
  def inflate(%Actor{primary_language_id: nil}=actor), do: actor
  def inflate(%Actor{primary_language_id: lang}=actor),
    do: %{actor | primary_language: Localisation.language!(lang)}

  @create_cast ~w(peer_id primary_language_id alias_id preferred_username signing_key)a
  @create_required ~w(preferred_username primary_language_id)a

  @spec create_changeset(Pointer.t(), map) :: Changeset.t()
  @doc "Creates a changeset for insertion from the given pointer and attrs"
  def create_changeset(%Pointer{id: id} = pointer, attrs) do
    Meta.assert_points_to!(pointer, __MODULE__)

    %Actor{id: id}
    |> Changeset.cast(attrs, @create_cast)
    |> Changeset.put_change(:is_public, true)
    |> Changeset.validate_required(@create_required)
    |> Changeset.validate_format(:preferred_username, @username_regex)
    |> Changeset.unique_constraint(:alias_id)
    |> Changeset.unique_constraint(:preferred_username, # with peer
      name: "mn_actor_preferred_username_peer_id_index"
    )
    |> validate_language_code(:primary_language_id)
    |> Changeset.unique_constraint(:preferred_username, # without peer (local)
      name: "mn_actor_peer_id_null_index"
    )
    |> meta_pointer_constraint()
    |> change_public()
  end

  @update_cast ~w(alias_id signing_key primary_language_id)a

  @spec update_changeset(%Actor{}, map) :: Changeset.t()
  @doc "Creates a changeset for updating the given actor from the given attrs"
  def update_changeset(%Actor{} = actor, attrs) do
    actor
    |> Changeset.cast(attrs, @update_cast)
    |> Changeset.unique_constraint(:alias_id)
    |> validate_language_code(:primary_language_id)
    |> meta_pointer_constraint()
    |> change_public()
  end

  def soft_delete_changeset(%Actor{} = actor),
    do: MoodleNet.Common.Changeset.soft_delete_changeset(actor)

end
