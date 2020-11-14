defmodule CommonsPub.Workers.APReceiverWorker do
  @moduledoc """
  Process queued-up incoming activities using `CommonsPub.ActivityPub.Receiver`
  """
  use ActivityPub.Workers.WorkerHelper, queue: "ap_incoming"

  @impl Oban.Worker

  def perform(%{args: %{"op" => "handle_activity", "activity" => activity}}) do
    CommonsPub.ActivityPub.Receiver.receive_activity(activity)
  end

  def perform(%{args: %{"op" => "handle_activity", "activity_id" => activity_id}}) do
    CommonsPub.ActivityPub.Receiver.receive_activity(activity_id)
  end
end
