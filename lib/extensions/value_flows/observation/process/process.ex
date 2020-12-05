defmodule ValueFlows.Observation.Process do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_process",
    table_id: "WAYF0R1NPVTST0BEC0ME0VTPVT"

  import CommonsPub.Common.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  alias CommonsPub.Users.User
  #
  # alias CommonsPub.Communities.Community
  alias ValueFlows.Observation.Process
  # alias Measurement.Measure

  # alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ProcessSpecification

  # alias ValueFlows.Observation.EconomicEvent

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    # belongs_to(:image, CommonsPub.Uploads.Content)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)

    field(:finished, :boolean, default: false)

    field(:classified_as, {:array, :string}, virtual: true)

    belongs_to(:based_on, ProcessSpecification)

    belongs_to(:context, Pointers.Pointer)

    # TODO
    # workingAgents: [Agent!]

    # trace: [EconomicEvent!]
    # track: [EconomicEvent!]

    # inputs(action: ID): [EconomicEvent!]
    # outputs(action: ID): [EconomicEvent!]
    # unplannedEconomicEvents(action: ID): [EconomicEvent!]

    # nextProcesses: [Process!]
    # previousProcesses: [Process!]
    # intendedInputs(action: ID): [Process!]
    # intendedOutputs(action: ID): [Process!]

    # committedInputs(action: ID): [Commitment!]
    # committedOutputs(action: ID): [Commitment!]
    # plannedWithin: Plan
    # nestedIn: Scenario

    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    belongs_to(:creator, User)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, CommonsPub.Tag.Taggable,
      join_through: "tags_things",
      unique: true,
      join_keys: [pointer_id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public)a
  @cast @required ++ ~w(note has_beginning has_end finished is_disabled context_id based_on_id)a

  def create_changeset(
        %User{} = creator,
        attrs
      ) do
    %Process{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> common_changeset()
  end

  def update_changeset(%Process{} = process, attrs) do
    process
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end

  def context_module, do: ValueFlows.Observation.Process.Processes

  def queries_module, do: ValueFlows.Observation.Process.Queries

  def follow_filters, do: [:default]
end
